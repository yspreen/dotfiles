#!/bin/bash

PID_FILE="$HOME/.spotify.pid"
TOKEN_FILE="$HOME/.spotify.token"
REFRESH_TOKEN_FILE="$HOME/.spotify.refresh_token"
CODE_VERIFIER_FILE="$HOME/.spotify.code_verifier"
TOKEN_EXPIRY_FILE="$HOME/.spotify.token_expiry"

SPOTIFY_CLIENT_ID="504c3a228e134c52b9ebbb5a0fe81bb8"
SPOTIFY_REDIRECT_URI="https://menubarspotify.spreen.co/success"
SPOTIFY_AUTH_URL="https://accounts.spotify.com/authorize"
SPOTIFY_TOKEN_URL="https://accounts.spotify.com/api/token"
SPOTIFY_API_URL="https://api.spotify.com/v1/me/player/currently-playing"
SPOTIFY_SCOPES="user-read-playback-state user-read-currently-playing"

# Function to check internet connectivity
check_internet_connectivity() {
    # Try to reach a reliable DNS server
    if ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        return 0 # Internet is available
    else
        return 1 # Internet is not available
    fi
}

if ! command -v magick &>/dev/null; then
    brew install magick
fi
if ! command -v jq &>/dev/null; then
    brew install jq
fi
if ! command -v curl &>/dev/null; then
    brew install curl
fi
if ! command -v openssl &>/dev/null; then
    brew install openssl
fi

# Kill existing process if running
if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null || true
    rm "$PID_FILE"
fi

rm "$HOME"/.spotify.*.jpg 2>/dev/null

# Modified generate_pkce_codes function to generate proper URL-safe PKCE codes
generate_pkce_codes() {
    CODE_VERIFIER=$(openssl rand -base64 96 | tr -dc 'a-zA-Z0-9-._~' | cut -c1-128)
    CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
    echo "$CODE_VERIFIER" >"$CODE_VERIFIER_FILE"
}

# Authenticate Spotify with PKCE
authenticate_spotify() {
    generate_pkce_codes
    echo "DEBUG: Generated PKCE codes" >>/tmp/spotify.log
    echo "Open the following URL in your browser to authorize access:" >>/tmp/spotify.log
    echo "${SPOTIFY_AUTH_URL}?client_id=${SPOTIFY_CLIENT_ID}&response_type=code&redirect_uri=${SPOTIFY_REDIRECT_URI}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256&scope=$(echo ${SPOTIFY_SCOPES} | sed 's/ /%20/g')" >>/tmp/spotify.log
    echo "${SPOTIFY_AUTH_URL}?client_id=${SPOTIFY_CLIENT_ID}&response_type=code&redirect_uri=${SPOTIFY_REDIRECT_URI}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256&scope=$(echo ${SPOTIFY_SCOPES} | sed 's/ /%20/g')" | pbcopy

    echo "We copied the URL to your clipboard. Please copy the code after signing in." >>/tmp/spotify.log
    sleep 1

    # Added timeout to avoid infinite loop waiting for the auth code.
    timeout=30
    elapsed=0
    while [ "$(pbpaste | grep -c '^https://')" -eq 1 ]; do
        echo "DEBUG: Waiting for auth code. Elapsed: $elapsed seconds" >>/tmp/spotify.log
        sleep 1
        elapsed=$((elapsed + 1))
        if [ "$elapsed" -ge "$timeout" ]; then
            echo "Timeout waiting for authorization code."
            exit 1
        fi
    done
    SPOTIFY_AUTH_CODE="$(pbpaste)"

    CODE_VERIFIER=$(cat "$CODE_VERIFIER_FILE")

    AUTH_RESPONSE=$(curl -s -X POST "$SPOTIFY_TOKEN_URL" \
        -d "client_id=${SPOTIFY_CLIENT_ID}" \
        -d "grant_type=authorization_code" \
        -d "code=${SPOTIFY_AUTH_CODE}" \
        -d "redirect_uri=${SPOTIFY_REDIRECT_URI}" \
        -d "code_verifier=${CODE_VERIFIER}")
    echo "DEBUG: Auth response: $AUTH_RESPONSE" >>/tmp/spotify.log

    SPOTIFY_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token')
    SPOTIFY_REFRESH_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.refresh_token')

    if [ "$SPOTIFY_TOKEN" != "null" ] && [ -n "$SPOTIFY_TOKEN" ]; then
        echo "$SPOTIFY_TOKEN" >"$TOKEN_FILE"
        echo "$SPOTIFY_REFRESH_TOKEN" >"$REFRESH_TOKEN_FILE"
        # Calculate and store token expiry (subtract 60 sec as buffer)
        expires_in=$(echo "$AUTH_RESPONSE" | jq -r '.expires_in')
        current_time=$(date +%s)
        token_expiry=$((current_time + expires_in - 60))
        echo "$token_expiry" >"$TOKEN_EXPIRY_FILE"
        echo "Spotify token obtained." >>/tmp/spotify.log
    else
        echo "Failed to authenticate with Spotify." >>/tmp/spotify.log
        echo $AUTH_RESPONSE >>/tmp/spotify.log
        exit 1
    fi
}

# Refresh Spotify Token
refresh_spotify_token() {
    echo "DEBUG: Starting token refresh." >>/tmp/spotify.log

    # Check for internet connectivity before attempting to refresh
    if ! check_internet_connectivity; then
        echo "DEBUG: No internet connection available. Skipping token refresh." >>/tmp/spotify.log
        return 1 # Return error code to indicate refresh was skipped
    fi

    SPOTIFY_REFRESH_TOKEN=$(cat "$REFRESH_TOKEN_FILE")
    REFRESH_RESPONSE=$(curl -s -X POST "$SPOTIFY_TOKEN_URL" \
        -d "client_id=${SPOTIFY_CLIENT_ID}" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=${SPOTIFY_REFRESH_TOKEN}")
    echo "DEBUG: Refresh response: $REFRESH_RESPONSE" >>/tmp/spotify.log

    error=$(echo "$REFRESH_RESPONSE" | jq -r '.error')
    if [ "$error" != "null" ]; then
        echo "DEBUG: Refresh error detected: $error" >>/tmp/spotify.log
        echo "DEBUG: Error description: $(echo "$REFRESH_RESPONSE" | jq -r '.error_description')" >>/tmp/spotify.log
        echo "Failed to refresh Spotify token due to error: $error. Re-authentication required." >>/tmp/spotify.log

        # Only re-authenticate if we have internet connectivity
        if check_internet_connectivity; then
            authenticate_spotify
        else
            echo "DEBUG: No internet connection available. Skipping re-authentication." >>/tmp/spotify.log
        fi
        return 1
    fi

    SPOTIFY_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.access_token')
    if [ "$SPOTIFY_TOKEN" != "null" ] && [ -n "$SPOTIFY_TOKEN" ]; then
        echo "$SPOTIFY_TOKEN" >"$TOKEN_FILE"
        # Optionally update refresh token if provided
        NEW_REFRESH_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.refresh_token')
        if [ "$NEW_REFRESH_TOKEN" != "null" ] && [ -n "$NEW_REFRESH_TOKEN" ]; then
            echo "$NEW_REFRESH_TOKEN" >"$REFRESH_TOKEN_FILE"
        fi
        # Update token expiry using refresh response
        expires_in=$(echo "$REFRESH_RESPONSE" | jq -r '.expires_in')
        current_time=$(date +%s)
        token_expiry=$((current_time + expires_in - 60))
        echo "$token_expiry" >"$TOKEN_EXPIRY_FILE"
        echo "DEBUG: Token refresh successful." >>/tmp/spotify.log
        echo "Spotify token refreshed." >>/tmp/spotify.log
        # Added extra logging to inspect new tokens.
        echo "DEBUG: New Access Token: $SPOTIFY_TOKEN" >>/tmp/spotify.log
        echo "DEBUG: New Refresh Token: $(cat "$REFRESH_TOKEN_FILE")" >>/tmp/spotify.log
    else
        echo "DEBUG: Token refresh failed, re-authentication required." >>/tmp/spotify.log
        echo "DEBUG: Refresh response did not include access_token." >>/tmp/spotify.log
        echo "Failed to refresh Spotify token. Re-authentication required." >>/tmp/spotify.log
        authenticate_spotify
    fi
}

# Add global variable to track last downloaded cover URL
LAST_COVER_URL=""

run_loop() {
    # Proactive token expiry check
    if [ -f "$TOKEN_EXPIRY_FILE" ]; then
        current_time=$(date +%s)
        expiry=$(cat "$TOKEN_EXPIRY_FILE")
        if [ "$current_time" -ge "$expiry" ]; then
            echo "DEBUG: Token expired proactively, refreshing token." >>/tmp/spotify.log
            refresh_spotify_token
        fi
    fi
    if [ ! -f "$TOKEN_FILE" ]; then
        # Check for internet connectivity before attempting authentication
        if check_internet_connectivity; then
            authenticate_spotify
        else
            echo "DEBUG: No internet connection available. Skipping authentication." >>/tmp/spotify.log
            sleep 30
            return
        fi
    fi
    SPOTIFY_TOKEN=$(cat "$TOKEN_FILE")

    response_with_code=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $SPOTIFY_TOKEN" "$SPOTIFY_API_URL")
    http_code=$(echo "$response_with_code" | tail -n1)
    response=$(echo "$response_with_code" | sed '$d')
    echo $response_with_code >>/tmp/spotify.log
    echo "DEBUG: API call returned http_code: $http_code" >>/tmp/spotify.log

    if [ "$http_code" -eq 401 ]; then
        echo "DEBUG: 401 Unauthorized response details: $response" >>/tmp/spotify.log

        # Check for internet connectivity before assuming auth failure
        if ! check_internet_connectivity; then
            echo "DEBUG: No internet connection available. Ignoring 401 error." >>/tmp/spotify.log
            sleep 30
            return
        fi

        echo "DEBUG: Internet is available. 401 Unauthorized response received. Refreshing token." >>/tmp/spotify.log
        refresh_spotify_token
        # Immediately reload token and retry API call
        SPOTIFY_TOKEN=$(cat "$TOKEN_FILE")
        response_with_code=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $SPOTIFY_TOKEN" "$SPOTIFY_API_URL")
        http_code=$(echo "$response_with_code" | tail -n1)
        response=$(echo "$response_with_code" | sed '$d')
        if [ "$http_code" -eq 401 ]; then
            echo "DEBUG: Still received 401 after token refresh, details: $response" >>/tmp/spotify.log
            sleep 5
            return
        fi
    fi

    if [ "$http_code" -eq 204 ]; then
        echo "No song playing. Waiting..." >>/tmp/spotify.log
        sleep 30
        return
    fi

    if [ "$http_code" -ne 200 ]; then
        # Check if we have internet connectivity before retrying
        if ! check_internet_connectivity; then
            echo "DEBUG: No internet connection available. Waiting before retry." >>/tmp/spotify.log
        else
            echo "Failed to fetch Spotify data. Retrying" >>/tmp/spotify.log
        fi
        sleep 30
        return
    fi

    cover_url=$(echo "$response" | jq -r '.item.album.images[0].url')
    progress_ms=$(echo "$response" | jq -r '.progress_ms')
    duration_ms=$(echo "$response" | jq -r '.item.duration_ms')

    seconds_left=$(((duration_ms - progress_ms) / 1000))
    if [ "$seconds_left" -gt 30 ]; then
        sleep_duration=30
    else
        sleep_duration=$seconds_left
    fi

    if [ "$cover_url" != "$LAST_COVER_URL" ]; then
        LAST_COVER_URL="$cover_url"
        rm "$HOME"/.spotify.*.jpg 2>/dev/null
        uuid=$(uuidgen)
        file_path="$HOME/.spotify.${uuid}.jpg"
        curl -s "$cover_url" -o "$file_path"
        # convert to 128x128:
        magick convert "$file_path" -resize 128x128\! "$file_path"
        sketchybar --set spotify icon.background.image="$file_path"
    fi

    sleep "$sleep_duration"
}

bg() {
    sleep 1
    MY_PID=$(cat "$PID_FILE")
    while [ "$(cat "$PID_FILE")" = "$MY_PID" ]; do # added quotes for safe comparison
        run_loop
    done
}

bg &
echo $! >"$PID_FILE"
