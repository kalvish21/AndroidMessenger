package com.androidmessenger.activities;

import android.app.Activity;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.MenuItem;
import android.widget.Toast;

import com.androidmessenger.connections.DesktopWebserverService;
import com.androidmessenger.util.RequestUtil;
import com.androidmessenger.util.UserPreferencesManager;

import org.json.JSONArray;
import org.json.JSONException;

import java.io.IOException;
import java.io.Serializable;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;

import me.dm7.barcodescanner.zbar.Result;
import me.dm7.barcodescanner.zbar.ZBarScannerView;

/**
 * Created by Kalyan Vishnubhatla on 8/28/16.
 */
public class QRScannerActivity extends AppCompatActivity implements Serializable, ZBarScannerView.ResultHandler {
    private final static String TAG = QRScannerActivity.class.getSimpleName();
    private static final long serialVersionUID = 3939250407605584685L;
    private ZBarScannerView mScannerView;

    private Integer failurCount = 0;

    public void onCreate(Bundle state) {
        super.onCreate(state);
        getSupportActionBar().setDisplayHomeAsUpEnabled(true);
        mScannerView = new ZBarScannerView(this);

        setContentView(mScannerView);
    }

    public void onResume() {
        super.onResume();
        mScannerView.setResultHandler(this);
        mScannerView.startCamera();
    }

    public void onPause() {
        super.onPause();
        mScannerView.stopCamera();
    }

    public void handleResult(Result result) {
        // Do something with the result here
        Log.v(TAG, result.getContents());
        Log.v(TAG, result.getBarcodeFormat().toString());

        failurCount = 0;
        try {
            final JSONArray array = new JSONArray(result.getContents().toString());
            CheckIfIPIsAttainable task = new CheckIfIPIsAttainable();
            task.execute(new JSONArray[]{array});

        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home: {
                finish();
                break;
            }

            default: {
                break;
            }
        }
        return true;
    }

    public class CheckIfIPIsAttainable extends AsyncTask<JSONArray, Void, Boolean> {

        String url = null;
        protected Boolean doInBackground(JSONArray... arrays) {
            try {
                JSONArray array = arrays[0];
                for (int i = 0; i < array.length(); ++i) {
                    url = String.format("http://%s:%s/", array.getString(i), DesktopWebserverService.PORT_NUMBER);

                    try {
                        if (isHostReachable(array.getString(i), Integer.parseInt(DesktopWebserverService.PORT_NUMBER), 3000)) {
                            return true;
                        } else {
                            ++failurCount;
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            } catch (Exception e){
                e.printStackTrace();
            }
            return false;
        }

        protected void onPostExecute(Boolean returned) {
            if (returned) {
                UserPreferencesManager.getInstance().setStringInPreferences(QRScannerActivity.this, RequestUtil.BASE_URL, url);
                Toast.makeText(QRScannerActivity.this, "Connected!", Toast.LENGTH_LONG).show();
                mScannerView.stopCamera();
            } else {
                Toast.makeText(QRScannerActivity.this, "QR was invalid or IP Address is unreachable.", Toast.LENGTH_LONG).show();
                mScannerView.startCamera();
            }

            Intent data = new Intent();
            data.putExtra("result", returned);
            setResult(Activity.RESULT_OK, data);
            finish();
        }

        public boolean isHostReachable(String serverAddress, int tcpPort, int timeoutInMillis){
            boolean connected = false;
            Socket socket;
            try {
                socket = new Socket();
                SocketAddress socketAddress = new InetSocketAddress(serverAddress, tcpPort);
                socket.connect(socketAddress, timeoutInMillis);
                if (socket.isConnected()) {
                    connected = true;
                    socket.close();
                }
            } catch (IOException e) {
                e.printStackTrace();
            } finally {
                socket = null;
            }
            return connected;
        }
    }
}
