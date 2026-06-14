/*
 * SPDX-FileCopyrightText: 2024 Andrew Gunnerson
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.extension

import android.database.Cursor

fun Cursor.asSequence() = generateSequence(seed = takeIf { it.moveToFirst() }) {
    takeIf { it.moveToNext() }
}
