package com.termux.app.termuxplus;

import android.content.Context;

import com.termux.app.TermuxActivity;
import com.termux.shared.termux.TermuxConstants;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Termux Plus: built-in terminal color scheme switcher.
 *
 * The color schemes live in the APK assets under "termux-plus/themes/*.properties"
 * (bundled at build time from the setup/themes directory of the Termux Plus repo).
 *
 * Applying a scheme writes it to ~/.termux/colors.properties — the exact same file
 * the external Termux:Styling app writes — and then triggers the exact same
 * ACTION_RELOAD_STYLE broadcast, so the change applies instantly, without
 * restarting the app or losing terminal sessions.
 *
 * The shell command "ttheme" (installed by the Termux Plus setup script) writes
 * the same file with the same "# termux-plus-theme: <name>" header, so the app
 * and the CLI always agree on what the current theme is.
 */
public class TermuxPlusThemes {

    /** Marker line written at the top of colors.properties to remember the active theme. */
    public static final String THEME_MARKER_PREFIX = "# termux-plus-theme: ";

    private static final String THEMES_ASSET_DIR = "termux-plus/themes";

    /** Returns the sorted list of bundled theme names (file names without extension). */
    public static List<String> getThemeNames(Context context) {
        List<String> names = new ArrayList<>();
        try {
            String[] files = context.getAssets().list(THEMES_ASSET_DIR);
            if (files != null) {
                Arrays.sort(files, String.CASE_INSENSITIVE_ORDER);
                for (String file : files) {
                    if (file != null && file.endsWith(".properties")) {
                        names.add(file.substring(0, file.length() - ".properties".length()));
                    }
                }
            }
        } catch (IOException e) {
            // No themes bundled; return empty list.
        }
        return names;
    }

    /** Pretty display name for a theme key: "tokyo-night" -> "Tokyo Night". */
    public static String getDisplayName(String name) {
        if (name == null || name.isEmpty()) return "Unknown";
        String s = name.replace('-', ' ');
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    /**
     * Returns the key of the currently active theme, or null when the colors file
     * does not exist (built-in default colors) or was not written by Termux Plus
     * (e.g. custom file or the external styling app).
     */
    public static String getCurrentTheme() {
        File file = TermuxConstants.TERMUX_COLOR_PROPERTIES_FILE;
        if (file == null || !file.exists()) return null;

        BufferedReader reader = null;
        try {
            reader = new BufferedReader(new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8));
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.startsWith(THEME_MARKER_PREFIX)) {
                    String name = line.substring(THEME_MARKER_PREFIX.length()).trim();
                    return name.isEmpty() ? null : name;
                }
            }
        } catch (IOException e) {
            return null;
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException ignored) {
                }
            }
        }
        return null;
    }

    /**
     * Applies the theme with the given name and reloads terminal styling live.
     *
     * @return true if the theme was found, written and the reload broadcast was sent.
     */
    public static boolean applyTheme(Context context, String name) {
        if (context == null || name == null || name.isEmpty()) return false;
        // Only allow plain theme keys; prevents any path tricks from UI values.
        if (!name.matches("[a-zA-Z0-9][a-zA-Z0-9._-]*")) return false;

        StringBuilder content = new StringBuilder();
        BufferedReader reader = null;
        try {
            reader = new BufferedReader(new InputStreamReader(
                context.getAssets().open(THEMES_ASSET_DIR + "/" + name + ".properties"), StandardCharsets.UTF_8));
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append('\n');
            }
        } catch (IOException e) {
            return false;
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException ignored) {
                }
            }
        }

        if (!writeColorsFile(content.toString())) return false;

        TermuxActivity.updateTermuxActivityStyling(context, true);
        return true;
    }

    /**
     * Removes colors.properties so the terminal falls back to the built-in
     * default colors, then reloads terminal styling live.
     *
     * @return true on success.
     */
    public static boolean resetTheme(Context context) {
        if (context == null) return false;
        File file = TermuxConstants.TERMUX_COLOR_PROPERTIES_FILE;
        if (file != null && file.exists() && !file.delete()) return false;

        TermuxActivity.updateTermuxActivityStyling(context, true);
        return true;
    }

    private static boolean writeColorsFile(String content) {
        File file = TermuxConstants.TERMUX_COLOR_PROPERTIES_FILE;
        if (file == null) return false;

        File parent = file.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) return false;

        Writer writer = null;
        try {
            writer = new OutputStreamWriter(new FileOutputStream(file), StandardCharsets.UTF_8);
            writer.write(content);
            writer.flush();
            return true;
        } catch (IOException e) {
            return false;
        } finally {
            if (writer != null) {
                try {
                    writer.close();
                } catch (IOException ignored) {
                }
            }
        }
    }

}
