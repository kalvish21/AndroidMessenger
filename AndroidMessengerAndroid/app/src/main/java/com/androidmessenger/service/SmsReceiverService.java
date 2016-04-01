package com.androidmessenger.service;

import android.annotation.TargetApi;
import android.app.IntentService;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.support.v4.BuildConfig;
import android.util.Log;


/**
 * Created by Kalyan Vishnubhatla on 9/8/15.
 */
public class SmsReceiverService extends IntentService {
    private static final String TAG = SmsReceiverService.class.getSimpleName();

    private static final String ACTION_SMS_RECEIVED = "android.provider.Telephony.SMS_RECEIVED";
    private static final String ACTION_MMS_RECEIVED = "android.provider.Telephony.WAP_PUSH_RECEIVED";
    private static final String ACTION_MESSAGE_RECEIVED = "net.everythingandroid.smspopup.MESSAGE_RECEIVED";
    private static final String MMS_DATA_TYPE = "application/vnd.wap.mms-message";
    public static final String MESSAGE_SENT_ACTION = "com.android.mms.transaction.MESSAGE_SENT";

    /*
     * This is the number of retries and pause between retries that we will keep checking the system
     * message database for the latest incoming message
     */
    private static final int MESSAGE_RETRY = 8;
    private static final int MESSAGE_RETRY_PAUSE = 1000;

    private Context context;
    private int mResultCode;
    private boolean serviceRestarted = false;

    private static final int TOAST_HANDLER_MESSAGE_SENT = 0;
    private static final int TOAST_HANDLER_MESSAGE_SEND_LATER = 1;
    private static final int TOAST_HANDLER_MESSAGE_FAILED = 2;
    private static final int TOAST_HANDLER_MESSAGE_CUSTOM = 3;

    public SmsReceiverService() {
        super(TAG);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        context = getApplicationContext();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        serviceRestarted = false;
        if ((flags & START_FLAG_REDELIVERY) !=0) {
            serviceRestarted = true;
        }
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        if (BuildConfig.DEBUG)
            Log.v(TAG, "SMSReceiverService: doWakefulWork()");

        mResultCode = 0;
        if (intent != null && !serviceRestarted) {
            mResultCode = intent.getIntExtra("result", 0);
            final String action = intent.getAction();
            final String dataType = intent.getType();

            if (ACTION_SMS_RECEIVED.equals(action)) {
                handleSmsReceived(intent);
            } else if (ACTION_MMS_RECEIVED.equals(action) && MMS_DATA_TYPE.equals(dataType)) {
                handleMmsReceived(intent);
            } else if (MESSAGE_SENT_ACTION.equals(action)) {
                handleSmsSent(intent);
            } else if (ACTION_MESSAGE_RECEIVED.equals(action)) {
                handleMessageReceived(intent);
            }
        }
        //SmsReceiver.completeWakefulIntent(intent);
    }

    /**
     * Handle receiving a SMS message
     */
    @TargetApi(Build.VERSION_CODES.KITKAT)
    private void handleSmsReceived(Intent intent) {
        if (BuildConfig.DEBUG)
            Log.v(TAG, "SMSReceiver: Intercept SMS");
    }

    /**
     * Handle receiving a MMS message
     */
    private void handleMmsReceived(Intent intent) {
        if (BuildConfig.DEBUG)
            Log.v(TAG, "MMS received!");
    }

    /**
     * Handle receiving an arbitrary message (potentially coming from a 3rd party app)
     */
    private void handleMessageReceived(Intent intent) {
        if (BuildConfig.DEBUG)
            Log.v(TAG, "SMSReceiver: Intercept Message");

        Bundle bundle = intent.getExtras();

        /*
         * FROM: ContactURI -or- display name and display address -or- display address MESSAGE BODY:
         * message body TIMESTAMP: optional (will use system timestamp)
         *
         * QUICK REPLY INTENT: REPLY INTENT: DELETE INTENT:
         */

        if (bundle != null) {

            // notifySmsReceived(new SmsMmsMessage(context, messages, System.currentTimeMillis()));
        }
    }

    /*
     * Handle the result of a sms being sent
     */
    private void handleSmsSent(Intent intent) {
    }
}
