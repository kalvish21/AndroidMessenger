package com.androidmessenger.activities;

import android.Manifest;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;
import android.os.StrictMode;
import android.support.v4.content.ContextCompat;
import android.support.v7.app.AppCompatActivity;
import android.text.format.Formatter;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.androidmessenger.R;
import com.androidmessenger.connections.WebServer;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.AlertUtil;
import com.androidmessenger.util.RequestUtil;
import com.androidmessenger.util.UserPreferencesManager;
import com.loopj.android.http.JsonHttpResponseHandler;

import org.apache.commons.lang3.ArrayUtils;
import org.json.JSONException;
import org.json.JSONObject;

import java.math.BigInteger;
import java.net.InetAddress;
import java.net.UnknownHostException;

import butterknife.ButterKnife;
import butterknife.OnClick;
import cz.msebera.android.httpclient.Header;

/**
 * Created by Kalyan Vishnubhatla on 3/21/16.
 */
public class Messenger extends AppCompatActivity {
    private static final String TAG = Messenger.class.getSimpleName();
    private Intent intent;
    private static final int READ_PHONE_STATE_PERMISSION = 1111;
    private static final int SEND_SMS_PERMISSION = 2222;
    private static final int READ_CONTACTS_PERMISSION = 3333;
    private static final int CAMERA_PERMISSION = 4444;


    private static final int QR_SCANNER = 4545;

    private BroadcastReceiver wifiReceiver;
    private BroadcastReceiver deviceUnpairReceiver;

    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_messenger);
        ButterKnife.bind(this);

        // Disable ipv6 on the simulator; it doesn't work
        if ("google_sdk".equals(Build.PRODUCT)) {
            java.lang.System.setProperty("java.net.preferIPv6Addresses", "false");
            java.lang.System.setProperty("java.net.preferIPv4Stack", "true");
        }

        if (UserPreferencesManager.getInstance().getValueFromPreferences(this, getString(R.string.preferences_should_autostart), "NO").equals("YES")) {
            startServers();
        }

        updateButtonsAndTextIfRequired();
        TextView textView = ButterKnife.findById(this, R.id.ipaddress);
        textView.setText(getIpAddress());


        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.GINGERBREAD) {
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);
        }

    }

    @Override
    protected void onResume() {
        super.onResume();

        if (deviceUnpairReceiver == null) {
            deviceUnpairReceiver = new BroadcastReceiver() {
                public void onReceive(Context context, Intent intent) {
                    updateButtonsAndTextIfRequired();
                }
            };
        }

        try {
            registerReceiver(deviceUnpairReceiver, new IntentFilter(getString(R.string.intent_filter_device_unpair)));
        } catch (Exception e) {
            // Probably was already registered
            e.printStackTrace();
        }

        if (wifiReceiver == null) {
            wifiReceiver = new BroadcastReceiver() {
                public void onReceive(Context context, Intent intent) {
                    boolean wifi = intent.getBooleanExtra("WIFI", false);
                    if (!wifi) {
                        TextView textView = ButterKnife.findById(Messenger.this, R.id.ipaddress);
                        textView.setText("DISCONNECTED");
                    } else {
                        TextView textView = ButterKnife.findById(Messenger.this, R.id.ipaddress);
                        textView.setText(getIpAddress());
                    }
                }
            };
        }

        try {
            registerReceiver(wifiReceiver, new IntentFilter(getString(R.string.intent_filter_wifi_changed)));
        } catch (Exception e) {
            // Probably was already registered
            e.printStackTrace();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();

        try {
            unregisterReceiver(deviceUnpairReceiver);
        } catch (Exception e) {
            // Probably wasn't registered in the first place
            e.printStackTrace();
        }

        try {
            unregisterReceiver(wifiReceiver);
        } catch (Exception e) {
            // Probably wasn't registered in the first place
            e.printStackTrace();
        }
    }

    private String getIpAddress() {
        try {
            WifiManager manager = (WifiManager) getSystemService(WIFI_SERVICE);
            WifiInfo wifiinfo = manager.getConnectionInfo();
            byte[] myIPAddress = BigInteger.valueOf(wifiinfo.getIpAddress()).toByteArray();
            ArrayUtils.reverse(myIPAddress);
            InetAddress myInetIP = InetAddress.getByAddress(myIPAddress);
            String ipAddress = myInetIP.getHostAddress();

            return ipAddress;

        } catch (UnknownHostException e) {
            e.printStackTrace();

            // Fallback on deprecated methods
            WifiManager wifiMgr = (WifiManager) getSystemService(WIFI_SERVICE);
            WifiInfo wifiInfo = wifiMgr.getConnectionInfo();
            int ip = wifiInfo.getIpAddress();
            String ipAddress = Formatter.formatIpAddress(ip);
            return ipAddress;
        }
    }

    private void updateButtonsAndTextIfRequired() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            int[] view_to_hide = new int[]{R.id.line_contacts_permissions, R.id.contacts_text, R.id.ask_contacts_permissions,
                    R.id.line_call_permissions, R.id.phone_call_text, R.id.ask_phone_call_permission};
            for (int viewInt : view_to_hide) {
                View view = ButterKnife.findById(this, viewInt);
                view.setVisibility(View.GONE);
            }
        } else {
            // Update the button if required
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                Button button = ButterKnife.findById(this, R.id.ask_contacts_permissions);
                button.setText(R.string.permission_granted);
                button.setEnabled(false);
            } else {
                Button button = ButterKnife.findById(this, R.id.ask_contacts_permissions);
                button.setText(R.string.button_text_contacts);
                button.setEnabled(true);
            }

            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                Button button = ButterKnife.findById(this, R.id.ask_phone_call_permission);
                button.setText(R.string.permission_granted);
                button.setEnabled(false);
            } else {
                Button button = ButterKnife.findById(this, R.id.ask_phone_call_permission);
                button.setText(R.string.button_text_call);
                button.setEnabled(true);
            }
        }

        // Set properties for the pairing/unpairing buttons and text
        String currentDevice = UserPreferencesManager.getInstance().getValueFromPreferences(this, getString(R.string.preferences_device_name));
        String currentUUID = UserPreferencesManager.getInstance().getValueFromPreferences(this, getString(R.string.preferences_device_uuid));
        if (currentDevice != null && currentUUID != null) {
            TextView deviceName = ButterKnife.findById(this, R.id.pairing_device_name);
            deviceName.setText(currentDevice);
            deviceName.setVisibility(View.VISIBLE);

            TextView pairingText = ButterKnife.findById(this, R.id.pairing_text);
            pairingText.setText(R.string.pairing_text);

            Button button = ButterKnife.findById(this, R.id.pairing_unpair);
            button.setText(R.string.pairing_unpair_button_text);
            button.setEnabled(true);

        } else {
            TextView deviceName = ButterKnife.findById(this, R.id.pairing_device_name);
            deviceName.setVisibility(View.GONE);

            TextView pairingText = ButterKnife.findById(this, R.id.pairing_text);
            pairingText.setText(R.string.pairing_text_none);

            Button button = ButterKnife.findById(this, R.id.pairing_unpair);
            button.setText(R.string.pairing_unpair_button_text);
            button.setEnabled(false);
        }
    }

    private void startServers() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            UserPreferencesManager.getInstance().setStringInPreferences(this, getString(R.string.preferences_should_autostart), "YES");
            intent = new Intent(this, AndroidAppService.class);
            intent.addCategory(AndroidAppService.TAG);
            startService(intent);
        } else {
            DialogInterface.OnClickListener listener = new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int which) {
                    switch (which) {
                        case DialogInterface.BUTTON_POSITIVE: {
                            askAllPermissionsAndStartServers();
                            break;
                        }

                        default: {
                            break;
                        }
                    }
                    ((AlertDialog) dialog).getButton(which).setVisibility(View.INVISIBLE);
                }
            };

            AlertUtil.showYesNoAlert(this, "Permissions Required", "This app requires permissions for basic phone state and SMS permissions. Click Yes to continue and provide these permissions or No to cancel.", listener);
        }
    }

    private void askAllPermissionsAndStartServers() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.READ_PHONE_STATE, Manifest.permission.CALL_PHONE}, READ_PHONE_STATE_PERMISSION);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.SEND_SMS, Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_MMS, Manifest.permission.RECEIVE_SMS}, SEND_SMS_PERMISSION);
        } else {
            startServers();
        }
    }

    @OnClick({R.id.start_button, R.id.stop_button, R.id.ask_contacts_permissions, R.id.ask_phone_call_permission, R.id.pairing_unpair, R.id.start_qr})
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.start_button: {
                startServers();
                break;
            }

            case R.id.stop_button: {
                UserPreferencesManager.getInstance().removeKeyFromPreferences(this, getString(R.string.preferences_should_autostart));
                stopService(intent);
                break;
            }

            case R.id.ask_contacts_permissions: {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                    DialogInterface.OnClickListener listener = new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(Messenger.this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(new String[]{Manifest.permission.READ_CONTACTS}, READ_PHONE_STATE_PERMISSION);
                            }
                            ((AlertDialog) dialog).getButton(which).setVisibility(View.INVISIBLE);
                        }
                    };

                    AlertUtil.showOkAlertWithListener(this, "Permissions Required", "By giving access to contacts, you will be able to search for contacts, make phone calls, and associate phone numbers with names on the desktop application.", listener);
                }
                break;
            }

            case R.id.ask_phone_call_permission: {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                    DialogInterface.OnClickListener listener = new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(Messenger.this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(new String[]{Manifest.permission.READ_PHONE_STATE, Manifest.permission.CALL_PHONE}, READ_PHONE_STATE_PERMISSION);
                            }
                            ((AlertDialog) dialog).getButton(which).setVisibility(View.INVISIBLE);
                        }
                    };

                    AlertUtil.showOkAlertWithListener(this, "Permissions Required", "By giving access to phone calling, you will be able to make calls to your contacts from the desktop application.", listener);
                }
                break;
            }

            case R.id.pairing_unpair: {
                UserPreferencesManager.getInstance().removeKeyFromPreferences(this, getString(R.string.preferences_device_name));
                UserPreferencesManager.getInstance().removeKeyFromPreferences(this, getString(R.string.preferences_device_uuid));
                stopService(intent);

                Intent intent = new Intent(getString(R.string.intent_filter_device_unpair));
                sendBroadcast(intent);
                break;
            }

            case R.id.start_qr: {
                startQRActivity();
                break;
            }

            default: {
                break;
            }
        }
    }

    private void startQRActivity() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.CAMERA}, CAMERA_PERMISSION);
        } else {
            Intent intent = new Intent(this, QRScannerActivity.class);
            startActivityForResult(intent, QR_SCANNER);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        switch (requestCode) {
            case QR_SCANNER: {
                if (data != null && data.hasExtra("result")) {
                    boolean result = data.getBooleanExtra("result", false);
                    if (result) {
                        try {
                            JSONObject obj = new JSONObject();
                            obj.put("ip", getIpAddress());
                            obj.put("port", WebServer.PORT_NUMBER);
                            RequestUtil.postJson(this, "/qr/connection", obj, new JsonHttpResponseHandler() {
                                @Override
                                public void onSuccess(int statusCode, Header[] headers, JSONObject response) {
                                    super.onSuccess(statusCode, headers, response);
                                }

                                @Override
                                public void onFailure(int statusCode, Header[] headers, Throwable throwable, JSONObject errorResponse) {
                                    super.onFailure(statusCode, headers, throwable, errorResponse);
                                }
                            });
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                }
                break;
            }

            default:{
                break;
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        switch (requestCode) {
            case READ_PHONE_STATE_PERMISSION: {
                // If request is cancelled, the result arrays are empty.
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    askAllPermissionsAndStartServers();
                } else {
                    AlertUtil.showOkAlert(this, "Error", "Permission was denied. Cannot read phone state. Please grant this permission under Permissions for Android Messenger.");
                }
                updateButtonsAndTextIfRequired();
                break;
            }

            case SEND_SMS_PERMISSION: {
                // If request is cancelled, the result arrays are empty.
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    askAllPermissionsAndStartServers();
                } else {
                    AlertUtil.showOkAlert(this, "Error", "Permission was denied. Cannot access SMS and MMS data. Please grant this permission under Permissions for Android Messenger.");
                }
                updateButtonsAndTextIfRequired();
                break;
            }

            case READ_CONTACTS_PERMISSION: {
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    askAllPermissionsAndStartServers();
                } else {
                    AlertUtil.showOkAlert(this, "Error", "Permission was denied. Cannot access Contacts. Please grant this permission under Permissions for Android Messenger.");
                }
                updateButtonsAndTextIfRequired();
                break;
            }

            case CAMERA_PERMISSION: {
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startQRActivity();
                } else {
                    AlertUtil.showOkAlert(this, "Error", "Permission was denied. Cannot access Camera. Please grant this permission under Permissions for Android Messenger.");
                }
                break;
            }

            default: {
                super.onRequestPermissionsResult(requestCode, permissions, grantResults);
                break;
            }
        }
    }
}
