package com.androidmessenger.util;

import android.net.Uri;

/**
 * Created by Kalyan Vishnubhatla on 9/15/15.
 */
public interface Constants {
    Uri Sms = Uri.parse("content://sms");
    Uri Mms = Uri.parse("content://mms");
    Uri MmsSms = Uri.parse("content://mms-sms/");
    Uri MmsPart = Uri.parse("content://mms/part");
}
