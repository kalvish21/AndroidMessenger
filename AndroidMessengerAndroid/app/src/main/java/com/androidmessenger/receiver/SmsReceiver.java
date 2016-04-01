package com.androidmessenger.receiver;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Message;
import android.support.v4.content.WakefulBroadcastReceiver;
import android.telephony.SmsMessage;
import android.util.Log;

import com.androidmessenger.BuildConfig;
import com.androidmessenger.service.AndroidAppService;

/**
 * Created by Kalyan Vishnubhatla on 9/8/15.
 */
public class SmsReceiver extends WakefulBroadcastReceiver {
    private static final String TAG = SmsReceiver.class.getSimpleName();

    public void onReceive(Context context, Intent intent) {
        if (BuildConfig.DEBUG) {
            Log.v(TAG, "SMSReceiver: onReceive()");
        }

        final Bundle bundle = intent.getExtras();
        try {
            if (bundle != null) {
                final Object[] pdus = (Object[]) bundle.get("pdus");
                SmsMessage[] messages = new SmsMessage[pdus.length];

                for (int i = 0; i < messages.length; i++) {

                    // Handle deprecated API
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        String format = bundle.getString("format");
                        messages[i] = SmsMessage.createFromPdu((byte[]) pdus[i], format);
                    } else {
                        messages[i] = SmsMessage.createFromPdu((byte[]) pdus[i]);
                    }

                    SmsMessage currentMessage = messages[i];
                    Bundle args = new Bundle();
                    args.putString("phoneNumber", currentMessage.getDisplayOriginatingAddress());
                    args.putLong("time", currentMessage.getTimestampMillis());
                    args.putString("message", currentMessage.getDisplayMessageBody());
                    args.putString("type", "sms");

                    Message msg = new Message();
                    msg.setData(args);
                    AndroidAppService.mServiceHandler.handleMessage(msg);

                }
            }

        } catch (Exception e) {
            Log.e("SmsReceiver", "Exception smsReceiver" + e);

        }
    }
}
