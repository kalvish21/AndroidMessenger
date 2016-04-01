package com.androidmessenger.activities;

import android.content.Context;
import android.content.Intent;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.telephony.TelephonyManager;
import android.text.format.Formatter;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import com.androidmessenger.R;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.Constants;
import com.androidmessenger.util.UserPreferencesManager;

import org.apache.commons.lang3.ArrayUtils;

import java.math.BigInteger;
import java.net.InetAddress;
import java.net.UnknownHostException;

import butterknife.ButterKnife;
import butterknife.OnClick;

/**
 * Created by Kalyan Vishnubhatla on 3/21/16.
 */
public class Messenger extends AppCompatActivity {
    private static final String TAG = Messenger.class.getSimpleName();
    private Intent intent;

    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_messenger);
        ButterKnife.bind(this);

        if ("google_sdk".equals( Build.PRODUCT )) {
            java.lang.System.setProperty("java.net.preferIPv6Addresses", "false");
            java.lang.System.setProperty("java.net.preferIPv4Stack", "true");
        }

        TextView textView = ButterKnife.findById(this, R.id.ipaddress);
        try {
            WifiManager manager = (WifiManager) getSystemService(WIFI_SERVICE);
            WifiInfo wifiinfo = manager.getConnectionInfo();
            byte[] myIPAddress = BigInteger.valueOf(wifiinfo.getIpAddress()).toByteArray();
            ArrayUtils.reverse(myIPAddress);
            InetAddress myInetIP = InetAddress.getByAddress(myIPAddress);
            String ipAddress = myInetIP.getHostAddress();
            textView.setText(ipAddress);

        } catch (UnknownHostException e) {
            e.printStackTrace();

            // Fallback on deprecated methods
            WifiManager wifiMgr = (WifiManager) getSystemService(WIFI_SERVICE);
            WifiInfo wifiInfo = wifiMgr.getConnectionInfo();
            int ip = wifiInfo.getIpAddress();
            String ipAddress = Formatter.formatIpAddress(ip);
            textView.setText(ipAddress);
        }

        // Users phone number -- Will need it later on
        TelephonyManager tMgr = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
        UserPreferencesManager.getInstance().setStringInPreferences(this, Constants.CURRENT_PHONENUMBER, tMgr.getLine1Number());

        if (UserPreferencesManager.getInstance().getValueFromPreferences(this, getString(R.string.preferences_key_should_autostart), "NO").equals("YES")) {
            startServers();
        }
    }

    private void startServers() {
        intent = new Intent(this, AndroidAppService.class);
        intent.addCategory(AndroidAppService.TAG);
        startService(intent);
    }

    @OnClick({R.id.start_button, R.id.stop_button})
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.start_button: {
                UserPreferencesManager.getInstance().setStringInPreferences(this, getString(R.string.preferences_key_should_autostart), "YES");
                startServers();

                break;
            }

            case R.id.stop_button: {
                UserPreferencesManager.getInstance().removeKeyFromPreferences(this, getString(R.string.preferences_key_should_autostart));
                stopService(intent);
                break;
            }

            default: {
                break;
            }
        }
    }
}
