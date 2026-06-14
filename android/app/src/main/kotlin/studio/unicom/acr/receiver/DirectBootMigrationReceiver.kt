/*
 * SPDX-FileCopyrightText: 2024 Andrew Gunnerson
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import studio.unicom.acr.service.DirectBootMigrationService

class DirectBootMigrationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        context.startService(Intent(context, DirectBootMigrationService::class.java))
    }
}
