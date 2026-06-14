/*
 * SPDX-FileCopyrightText: 2023-2026 Andrew Gunnerson
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.output

import android.content.Context
import android.telephony.TelephonyManager
import android.util.Log
import io.michaelrocks.libphonenumber.android.NumberParseException
import io.michaelrocks.libphonenumber.android.PhoneNumberUtil
import java.util.Locale

data class PhoneNumber(private val number: String) {
    init {
        require(number.isNotEmpty()) { "Number cannot be empty" }
    }

    fun format(context: Context, format: PhoneNumberUtil.PhoneNumberFormat): String? {
        val util = getUtil(context)
        val short = util.shortNumberInfo

        val country = getIsoCountryCode(context)
        if (country == null) {
            Log.w(TAG, "Failed to detect country")
            return null
        }

        val pn = try {
            util.parse(number, country)
        } catch (e: NumberParseException) {
            Log.w(TAG, "Unparseable phone number", e)
            return null
        } catch (e: RuntimeException) {
            Log.w(TAG, "Failed to parse phone number (metadata missing?)", e)
            return null
        }

        if (format != PhoneNumberUtil.PhoneNumberFormat.NATIONAL && short.isValidShortNumber(pn)) {
            Log.w(TAG, "Short numbers cannot be formatted with $format")
            return null
        }

        if (format != PhoneNumberUtil.PhoneNumberFormat.NATIONAL && !util.isValidNumber(pn)) {
            Log.w(TAG, "Invalid numbers cannot be formatted with $format")
            return null
        }

        return util.format(pn, format)
    }

    override fun toString(): String = number

    companion object {
        private val TAG = PhoneNumber::class.java.simpleName

        @Volatile
        private var utilInstance: PhoneNumberUtil? = null

        private fun getUtil(context: Context): PhoneNumberUtil {
            return utilInstance ?: synchronized(this) {
                utilInstance ?: PhoneNumberUtil.createInstance(context).also { utilInstance = it }
            }
        }

        /**
         * Get the current ISO country code for phone number formatting.
         */
        private fun getIsoCountryCode(context: Context): String? {
            val telephonyManager = context.getSystemService(TelephonyManager::class.java)
            var result: String? = null

            if (telephonyManager.phoneType == TelephonyManager.PHONE_TYPE_GSM) {
                result = telephonyManager.networkCountryIso
            }
            if (result.isNullOrEmpty()) {
                result = telephonyManager.simCountryIso
            }
            if (result.isNullOrEmpty()) {
                result = Locale.getDefault().country
            }
            if (result.isNullOrEmpty()) {
                return null
            }
            return result.uppercase()
        }
    }
}
