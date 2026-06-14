/*
 * SPDX-FileCopyrightText: 2023-2024 Andrew Gunnerson
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.extension

import android.telecom.Call
import studio.unicom.acr.output.PhoneNumber

val Call.Details.phoneNumber: PhoneNumber?
    get() = handle?.phoneNumber?.let {
        try {
            PhoneNumber(it)
        } catch (_: IllegalArgumentException) {
            null
        }
    }
