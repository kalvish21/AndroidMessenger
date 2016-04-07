package com.androidmessenger.receiver;

import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Bundle;
import android.os.Message;
import android.support.v4.content.WakefulBroadcastReceiver;

import com.androidmessenger.service.AndroidAppService;

/**
 * Created by Kalyan Vishnubhatla on 3/27/16.
 */
public class WifiReciever extends WakefulBroadcastReceiver {
    private static final String TAG = WifiReciever.class.getSimpleName();

    public void onReceive(Context context, Intent intent) {
        try {
            Bundle args = new Bundle();
            args.putBoolean("wifi", isConnectedToWifi(context));
            args.putString("call_type", "wifi");

            Message msg = new Message();
            msg.setData(args);
            AndroidAppService.mServiceHandler.handleMessage(msg);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static boolean isConnectedToWifi(Context context) {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
        return activeNetwork.getType() == ConnectivityManager.TYPE_WIFI && activeNetwork.isConnected();
    }
}
