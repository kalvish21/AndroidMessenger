package com.androidmessenger.service;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.Binder;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.PowerManager;
import android.support.annotation.Nullable;
import android.widget.Toast;

import com.androidmessenger.R;
import com.androidmessenger.connections.WebServer;
import com.androidmessenger.connections.WebSocket;
import com.androidmessenger.observer.SmsObserver;
import com.androidmessenger.receiver.WifiReciever;
import com.androidmessenger.util.Constants;
import com.androidmessenger.util.UserPreferencesManager;

import fi.iki.elonen.NanoHTTPD;

/**
 * Created by Kalyan Vishnubhatla on 3/24/16.
 */
public class AndroidAppService extends Service {
    public static final String TAG = AndroidAppService.class.getSimpleName();
    private Looper mServiceLooper;
    public static ServiceHandler mServiceHandler;

    private boolean connected;
    private WebSocket webSocket;
    private WebServer webServer;
    private SmsObserver content;
    private PowerManager.WakeLock wakeLock;

    @Override
    public void onCreate() {
        HandlerThread thread = new HandlerThread("ServiceStartArguments");
        thread.start();

        // Start servers
        if (WifiReciever.isConnectedToWifi(getBaseContext())) {
            startServers();
        }

        Intent intent = new Intent(this, AndroidAppService.class);
        bindService(intent, m_serviceConnection, BIND_AUTO_CREATE);

        // Get the HandlerThread's Looper and use it for our Handler
        mServiceLooper = thread.getLooper();
        mServiceHandler = new ServiceHandler(mServiceLooper, getBaseContext());

        // Broadcast receiver
        registerReceiver(new BroadcastReceiver() {
            public void onReceive(Context context, Intent intent) {
                String currentDevice = UserPreferencesManager.getInstance().getValueFromPreferences(context, getString(R.string.preferences_device_name));
                String currentUUID = UserPreferencesManager.getInstance().getValueFromPreferences(context, getString(R.string.preferences_device_uuid));
                if (currentDevice == null && currentUUID == null) {
                    // Close all connections if there are any
                    webSocket.closeAllConnections();
                }
            }
        }, new IntentFilter(getString(R.string.intent_filter_device_unpair)));
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // If we get killed, after returning from here, restart
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopServers();
    }

    public WebSocket getAndroidWebSocket() {
        return webSocket;
    }

    public void startServers() {
        if (!connected) {
            Toast.makeText(this, "Starting Android Messenger ...", Toast.LENGTH_LONG).show();
        }
        connected = true;
        try {
            if (webSocket == null) {
                webSocket = new WebSocket(this);
            }
            webSocket.start();
        } catch (IllegalStateException e) {
            // Already started
            e.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }

        try {
            if (webServer == null) {
                webServer = new WebServer(this);
                webServer.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Add observer
        content = new SmsObserver(new Handler(), this);
        getContentResolver().registerContentObserver(Constants.Sms, true, content);

        // Get wake lock
        if (wakeLock == null) {
            PowerManager powerManager = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AndroidAppServiceWakeLock");
            wakeLock.acquire();
        }
    }

    public void stopServers() {
        if (connected) {
            Toast.makeText(this, "Stopping Android Messenger ...", Toast.LENGTH_LONG).show();
        }
        connected = false;
        try {
            // Shut down websocket
            if (webSocket != null) {
                webSocket.closeAllConnectionsAndStop();
                webSocket = null;
            }

            // Shutdown webserver
            if (webServer != null) {
                webServer.stop();
                webServer = null;
            }

            // Remove observers
            getContentResolver().unregisterContentObserver(content);

            // Remove wakelock
            if (wakeLock != null) {
                wakeLock.release();
                wakeLock = null;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    AndroidAppService m_service;
    private ServiceConnection m_serviceConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            m_service = ((AndroidAppService.MyBinder)service).getService();
        }

        public void onServiceDisconnected(ComponentName className) {
            m_service = null;
        }
    };

    public class MyBinder extends Binder {
        public AndroidAppService getService() {
            return AndroidAppService.this;
        }
    }

    // Handler that receives messages from the thread
    public class ServiceHandler extends Handler {
        Context context;
        public ServiceHandler(Looper looper, Context context) {
            super(looper);
            this.context = context;
        }

        public void handleMessage(Message msg) {
            Bundle bundle = msg.getData();
            String callType = bundle.getString("call_type");

            switch (callType) {
                case "wifi": {
                    // Wifi state was changed
                    Boolean wifi = bundle.getBoolean("wifi");
                    if (wifi) {
                        AndroidAppService.this.startServers();
                    } else {
                        AndroidAppService.this.stopServers();
                    }

                    Intent intent = new Intent(getString(R.string.intent_filter_wifi_changed));
                    intent.putExtra("WIFI", wifi);
                    sendBroadcast(intent);

                    break;
                }

                default: {
                    break;
                }
            }
        }
    }
}
