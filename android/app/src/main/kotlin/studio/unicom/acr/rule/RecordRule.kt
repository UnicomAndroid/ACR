/*
 * SPDX-FileCopyrightText: 2023-2026 Andrew Gunnerson
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.rule

import android.content.Context
import android.os.Parcelable
import android.util.Log
import studio.unicom.acr.GroupLookup
import studio.unicom.acr.output.CallDirection
import studio.unicom.acr.output.PhoneNumber
import studio.unicom.acr.withContactGroupMemberships
import studio.unicom.acr.withContactsByPhoneNumber
import kotlinx.parcelize.Parcelize
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// We have no good way to deserialize LegacyAction into Action:
// https://github.com/Kotlin/kotlinx.serialization/issues/2460
// https://github.com/Kotlin/kotlinx.serialization/issues/2463
@Parcelize
@Serializable
data class LegacyRecordRule(
    @SerialName("call_number")
    val callNumber: RecordRule.CallNumber,
    @SerialName("call_type")
    val callType: RecordRule.CallType,
    @SerialName("sim_slot")
    val simSlot: RecordRule.SimSlot,
    @SerialName("action")
    val legacyAction: LegacyAction,
) : Parcelable {
    @Parcelize
    @Serializable
    enum class LegacyAction : Parcelable {
        SAVE,
        DISCARD,
        IGNORE;

        fun toAction(): RecordRule.Action = when (this) {
            SAVE -> RecordRule.Action.Save(initialState = RecordRule.InitialState.RECORDING)
            DISCARD -> RecordRule.Action.Discard(initialState = RecordRule.InitialState.RECORDING)
            IGNORE -> RecordRule.Action.Ignore
        }
    }

    fun toRecordRule() = RecordRule(callNumber, callType, simSlot, legacyAction.toAction())
}

/**
 * A rule specifies several conditions, which are ANDed together, and if a call matches, then the
 * specified action is taken.
 */
@Parcelize
@Serializable
data class RecordRule(
    @SerialName("call_number")
    val callNumber: CallNumber,
    @SerialName("call_type")
    val callType: CallType,
    @SerialName("sim_slot")
    val simSlot: SimSlot,
    val action: Action,
) : Parcelable {
    @Parcelize
    @Serializable
    sealed interface CallNumber : Parcelable {
        /**
         * Check if the condition matches the set of contacts in [contactLookupKeys] or contact groups
         * in [contactGroupIds], or raw phone [numbers].
         */
        fun matches(
            contactLookupKeys: Collection<String>,
            contactGroupIds: Collection<GroupLookup>,
            numbers: Collection<PhoneNumber> = emptySet(),
        ): Boolean

        @Parcelize
        @Serializable
        @SerialName("any")
        data object Any : CallNumber {
            override fun matches(
                contactLookupKeys: Collection<String>,
                contactGroupIds: Collection<GroupLookup>,
                numbers: Collection<PhoneNumber>,
            ): Boolean = true
        }

        @Parcelize
        @Serializable
        @SerialName("contact")
        data class Contact(val lookupKey: String) : CallNumber {
            override fun matches(
                contactLookupKeys: Collection<String>,
                contactGroupIds: Collection<GroupLookup>,
                numbers: Collection<PhoneNumber>,
            ): Boolean = lookupKey in contactLookupKeys
        }

        @Parcelize
        @Serializable
        @SerialName("contact_group")
        data class ContactGroup(val rowId: Long, val sourceId: String?) : CallNumber {
            override fun matches(
                contactLookupKeys: Collection<String>,
                contactGroupIds: Collection<GroupLookup>,
                numbers: Collection<PhoneNumber>,
            ): Boolean = contactGroupIds.any {
                when (it) {
                    is GroupLookup.RowId -> it.id == rowId
                    is GroupLookup.SourceId -> it.id == sourceId
                }
            }
        }

        @Parcelize
        @Serializable
        @SerialName("unknown")
        data object Unknown : CallNumber {
            override fun matches(
                contactLookupKeys: Collection<String>,
                contactGroupIds: Collection<GroupLookup>,
                numbers: Collection<PhoneNumber>,
            ): Boolean = contactLookupKeys.isEmpty()
        }

        /**
         * Match by phone number pattern with wildcard support.
         * `*` matches any sequence. Pattern is anchored (full string match).
         * Matching is performed against all number representations
         * (E.164, international, national, and raw).
         */
        @Parcelize
        @Serializable
        @SerialName("phone_pattern")
        data class PhonePattern(val pattern: String) : CallNumber {
            override fun matches(
                contactLookupKeys: Collection<String>,
                contactGroupIds: Collection<GroupLookup>,
                numbers: Collection<PhoneNumber>,
            ): Boolean {
                if (numbers.isEmpty()) return false
                val regexStr = Regex.escape(pattern).replace("\\*", ".*")
                val regex = Regex("^$regexStr$")
                return numbers.any { phoneNumber ->
                    // Match against the raw number string
                    regex.containsMatchIn(phoneNumber.toString())
                }
            }
        }
    }

    @Parcelize
    @Serializable
    enum class CallType : Parcelable {
        ANY,
        INCOMING,
        OUTGOING,
        CONFERENCE;

        fun matches(direction: CallDirection?): Boolean = when (this) {
            ANY -> true
            INCOMING -> direction == CallDirection.IN
            OUTGOING -> direction == CallDirection.OUT
            CONFERENCE -> direction == CallDirection.CONFERENCE
        }
    }

    @Parcelize
    @Serializable
    sealed interface SimSlot : Parcelable {
        fun matches(simSlot: Int?): Boolean

        @Parcelize
        @Serializable
        @SerialName("any")
        data object Any : SimSlot {
            override fun matches(simSlot: Int?): Boolean = true
        }

        @Parcelize
        @Serializable
        @SerialName("specific")
        data class Specific(val slot: Int) : SimSlot {
            override fun matches(simSlot: Int?): Boolean = simSlot == slot
        }
    }

    @Parcelize
    @Serializable
    enum class InitialState : Parcelable {
        RECORDING,
        PAUSED,
    }

    @Parcelize
    @Serializable
    sealed interface Action : Parcelable {
        /**
         * Save the recording when the call ends unless the user chooses to delete it during the
         * call via the notification.
         */
        @Parcelize
        @Serializable
        @SerialName("save")
        data class Save(val initialState: InitialState) : Action

        /**
         * Delete the recording when the call ends unless the user chooses to preserve it during the
         * call via the notification.
         */
        @Parcelize
        @Serializable
        @SerialName("discard")
        data class Discard(val initialState: InitialState) : Action

        /**
         * Completely ignore the call. [studio.unicom.acr.service.RecorderThread] will exit without writing
         * any output files. It is not possible to start a recording later for a matching call.
         */
        @Parcelize
        @Serializable
        @SerialName("ignore")
        data object Ignore : Action
    }

    companion object {
        private val TAG = RecordRule::class.java.simpleName

        /**
         * Evaluate list of rules to determine the action to take.
         *
         * @throws IllegalArgumentException if no [rules] match the call
         */
        fun evaluate(
            context: Context,
            rules: List<RecordRule>,
            numbers: Collection<PhoneNumber>,
            direction: CallDirection?,
            simSlot: Int?,
        ): Action {
            var contactLookupKeys = emptySet<String>()
            var contactGroupIds = emptySet<GroupLookup>()

            try {
                contactLookupKeys = hashSetOf<String>().apply {
                    for (number in numbers) {
                        withContactsByPhoneNumber(context, number) { contacts ->
                            contacts.map { it.lookupKey }.toCollection(this)
                        }
                    }
                }

                // Avoid doing group membership lookups if we don't need to.
                if (rules.any { it.callNumber is CallNumber.ContactGroup }) {
                    contactGroupIds = hashSetOf<GroupLookup>().apply {
                        for (lookupKey in contactLookupKeys) {
                            withContactGroupMemberships(context, lookupKey) {
                                it.toCollection(this)
                            }
                        }
                    }
                }
            } catch (e: SecurityException) {
                Log.w(TAG, "Permission denied when querying contacts and contact groups", e)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to query contacts and contact groups", e)
            }

            for (rule in rules) {
                val matches = rule.callNumber.matches(contactLookupKeys, contactGroupIds, numbers)
                        && rule.callType.matches(direction)
                        && rule.simSlot.matches(simSlot)

                if (matches) {
                    Log.i(TAG, "Matched rule: $rule")
                    return rule.action
                }
            }

            throw IllegalArgumentException("Call does not match any rule")
        }
    }
}
