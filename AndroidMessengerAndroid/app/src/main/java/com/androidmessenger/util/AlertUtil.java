package com.androidmessenger.util;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.view.View;

/**
 * Created by Kalyan Vishnubhatla on 9/8/15.
 */
public class AlertUtil {
    public static void showOkAlert(final Context context, String title, String message) {
        DialogInterface.OnClickListener listener = new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {
                ((AlertDialog) dialog).getButton(which).setVisibility(View.INVISIBLE);
            }
        };
        showOkAlertWithListener(context, title, message, listener);
    }

    public static void showOkAlertWithListener(final Context context, String title, String message, DialogInterface.OnClickListener dialogClickListener) {
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setTitle(title)
                .setMessage(message)
                .setPositiveButton("Ok", dialogClickListener)
                .show();
    }

    public static void showYesNoAlert(final Context context, String title, String message, DialogInterface.OnClickListener dialogClickListener) {
        showCustomButtonsAlertWithListener(context, "Yes", "No", title, message, dialogClickListener);
    }

    public static void showCustomButtonsAlertWithListener(final Context context, String positiveButtonText, String negativeButtonText, String title, String message, DialogInterface.OnClickListener dialogClickListener) {
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setTitle(title)
                .setMessage(message)
                .setPositiveButton(positiveButtonText, dialogClickListener)
                .setNegativeButton(negativeButtonText, dialogClickListener)
                .show();
    }

}
