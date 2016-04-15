package com.androidmessenger.observer;

import android.content.ContentResolver;
import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.net.Uri;
import android.os.Handler;
import android.provider.Telephony;
import android.telephony.PhoneNumberUtils;

import com.androidmessenger.util.Constants;

/**
 * Created by Kalyan Vishnubhatla on 4/15/16.
 */
public class SendingSmsObserver extends ContentObserver {
    private static final Handler handler = new Handler();

    private final OnSmsSentListener listener;
    private final ContentResolver resolver;
    private final String address, body, uuid;

    public interface OnSmsSentListener {
        void onSmsSent(Uri uri, String uuid);
    }

    public SendingSmsObserver(OnSmsSentListener listener, Context context, String address, String body, String uuid) {
        super(handler);

        this.listener = listener;
        this.resolver = context.getContentResolver();
        this.address = address;
        this.body = body;
        this.uuid = uuid;
    }

    public void start() {
        if (resolver != null) {
            resolver.registerContentObserver(Constants.Sms, true, this);
        } else {
            throw new IllegalStateException(
                    "Current SmsObserver instance is invalid");
        }
    }

    @Override
    public void onChange(boolean selfChange, Uri uri) {
        Cursor cursor = null;

        try {
            cursor = resolver.query(uri, null, null, null, null);

            if (cursor != null && cursor.moveToFirst()) {
                final int type = cursor.getInt(cursor.getColumnIndex(Telephony.Sms.TYPE));

                if (type == Telephony.Sms.Sent.MESSAGE_TYPE_SENT) {
                    final String address = cursor.getString(cursor.getColumnIndex(Telephony.Sms.ADDRESS));
                    final String body = cursor.getString(cursor.getColumnIndex(Telephony.Sms.BODY));
                    final String _id = cursor.getString(cursor.getColumnIndex(Telephony.Sms._ID));

                    if (PhoneNumberUtils.compare(address, this.address) && body.equals(this.body)) {
                        Uri sentSmsUri = Uri.parse(Constants.Sms + "/" + _id);
                        listener.onSmsSent(sentSmsUri, uuid);
                        resolver.unregisterContentObserver(this);
                    }
                }
            }
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }
}