package com.termux.app.fragments.settings;

import android.app.AlertDialog;
import android.content.Context;
import android.os.Bundle;

import androidx.annotation.Keep;
import androidx.preference.Preference;
import androidx.preference.PreferenceDataStore;
import androidx.preference.PreferenceFragmentCompat;
import androidx.preference.PreferenceManager;

import com.termux.R;
import com.termux.app.termuxplus.TermuxPlusThemes;
import com.termux.shared.logger.Logger;
import com.termux.shared.termux.settings.preferences.TermuxAppSharedPreferences;

import java.util.List;

@Keep
public class TermuxPreferencesFragment extends PreferenceFragmentCompat {

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        Context context = getContext();
        if (context == null) return;

        PreferenceManager preferenceManager = getPreferenceManager();
        preferenceManager.setPreferenceDataStore(TermuxPreferencesDataStore.getInstance(context));

        setPreferencesFromResource(R.xml.termux_preferences, rootKey);

        // Termux Plus: wire up the built-in color scheme switcher.
        configureTermuxPlusPreferences(context);
    }

    /**
     * Termux Plus: registers the click handlers for the "Termux Plus" preference
     * category (in-app color scheme picker and colors reset).
     */
    private void configureTermuxPlusPreferences(final Context context) {
        final Preference colorSchemePreference = findPreference("termux_plus_color_scheme");
        if (colorSchemePreference != null) {
            updateColorSchemeSummary(colorSchemePreference, context);

            colorSchemePreference.setOnPreferenceClickListener(preference -> {
                showColorSchemeDialog(context, colorSchemePreference);
                return true;
            });
        }

        Preference resetColorsPreference = findPreference("termux_plus_reset_colors");
        if (resetColorsPreference != null) {
            resetColorsPreference.setOnPreferenceClickListener(preference -> {
                if (TermuxPlusThemes.resetTheme(context)) {
                    Logger.showToast(context, context.getString(R.string.termux_plus_theme_reset_done), true);
                } else {
                    Logger.showToast(context, context.getString(R.string.termux_plus_theme_apply_failed), true);
                }
                updateColorSchemeSummary(colorSchemePreference, context);
                return true;
            });
        }
    }

    /** Termux Plus: shows the "Current: <theme>" summary under the color scheme entry. */
    private void updateColorSchemeSummary(Preference preference, Context context) {
        if (preference == null) return;
        String current = TermuxPlusThemes.getCurrentTheme();
        if (current != null) {
            preference.setSummary(context.getString(R.string.termux_plus_color_scheme_current,
                TermuxPlusThemes.getDisplayName(current)));
        } else {
            preference.setSummary(context.getString(R.string.termux_plus_color_scheme_current_default));
        }
    }

    /** Termux Plus: the color scheme picker dialog. Applies instantly on tap. */
    private void showColorSchemeDialog(final Context context, final Preference preference) {
        List<String> themeNames = TermuxPlusThemes.getThemeNames(context);
        if (themeNames.isEmpty()) {
            Logger.showToast(context, context.getString(R.string.termux_plus_theme_none_found), true);
            return;
        }

        final String[] keys = themeNames.toArray(new String[0]);
        final String[] displayNames = new String[keys.length];
        String currentTheme = TermuxPlusThemes.getCurrentTheme();
        int checkedItem = -1;
        for (int i = 0; i < keys.length; i++) {
            displayNames[i] = TermuxPlusThemes.getDisplayName(keys[i]);
            if (keys[i].equals(currentTheme)) checkedItem = i;
        }

        new AlertDialog.Builder(context)
            .setTitle(R.string.termux_plus_theme_dialog_title)
            .setSingleChoiceItems(displayNames, checkedItem, (dialog, which) -> {
                String name = keys[which];
                if (TermuxPlusThemes.applyTheme(context, name)) {
                    Logger.showToast(context, context.getString(R.string.termux_plus_theme_applied,
                        TermuxPlusThemes.getDisplayName(name)), true);
                } else {
                    Logger.showToast(context, context.getString(R.string.termux_plus_theme_apply_failed), true);
                }
                updateColorSchemeSummary(preference, context);
                dialog.dismiss();
            })
            .setNegativeButton(android.R.string.cancel, null)
            .show();
    }

}

class TermuxPreferencesDataStore extends PreferenceDataStore {

    private final Context mContext;
    private final TermuxAppSharedPreferences mPreferences;

    private static TermuxPreferencesDataStore mInstance;

    private TermuxPreferencesDataStore(Context context) {
        mContext = context;
        mPreferences = TermuxAppSharedPreferences.build(context, true);
    }

    public static synchronized TermuxPreferencesDataStore getInstance(Context context) {
        if (mInstance == null) {
            mInstance = new TermuxPreferencesDataStore(context);
        }
        return mInstance;
    }

}
