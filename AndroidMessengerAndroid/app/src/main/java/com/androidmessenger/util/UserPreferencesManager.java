package com.androidmessenger.util;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Created by Kalyan Vishnubhatla on 3/22/16.
 */
public class UserPreferencesManager {
    public static final String USER_PROPERTIES = "USER_PROPERTIES_ANDROID_MESSENGER";

    private static UserPreferencesManager instance = new UserPreferencesManager();

    public static UserPreferencesManager getInstance() {
        return instance;
    }

    public String getValueFromPreferences(final Context context, String key) {
        return getValueFromPreferences(context, key, null);
    }

    public String getValueFromPreferences(final Context context, String key, String defaultValue) {
        if (context == null) {
            return defaultValue;
        }
        SharedPreferences preferences = context.getSharedPreferences(USER_PROPERTIES, Context.MODE_PRIVATE);
        return preferences.getString(key, defaultValue);
    }

    public void setStringInPreferences(final Context context, String key, String value) {
        SharedPreferences preferences = context.getSharedPreferences(USER_PROPERTIES, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit();

        editor.putString(key, value);
        editor.apply();
    }

    public void removeKeyFromPreferences(final Context context, String key) {
        SharedPreferences preferences = context.getSharedPreferences(USER_PROPERTIES, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit();

        editor.remove(key);
        editor.apply();
    }
}
