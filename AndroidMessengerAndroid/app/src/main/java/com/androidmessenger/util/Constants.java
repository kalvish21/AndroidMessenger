package com.androidmessenger.util;

import android.net.Uri;

/**
 * Created by Kalyan Vishnubhatla on 9/15/15.
 */
public interface Constants {
    String DEVICE_UUID = "DEVICE_UUID";
    String CURRENT_COUNTER = "CURRENT_COUNTER";
    String CURRENT_PHONENUMBER = "CURRENT_PHONENUMBER";

    Uri Sms = Uri.parse("content://sms");
    Uri Mms = Uri.parse("content://mms");
    Uri MmsPart = Uri.parse("content://mms/part");
}
