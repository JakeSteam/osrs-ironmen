#!/bin/bash

playlists_file="${WORKSPACE}/automation/playlists.txt"
template_file="${WORKSPACE}/automation/template.md"
output_file="${WORKSPACE}/README.md"

header_prefix="### "
placeholder_text="dynamic-playlist-data"
temp_output_file="output.json"
output=""

# Convert list of playlists into Markdown tables
while read -r line; do
    if [[ ${line} == ${header_prefix}* ]]; then
        echo "Adding header ${line}"
        output="${output}\n${line}\n\n"
        output="${output}| Playlist ↕ | Creator ↕ | # Videos ↕ | First video |\n| --- | --- | --- | --- |\n"
    else
        IFS=';' read -r playlist_id playlist_name emoji <<< "${line}" # Split line by semi-colon
        echo "Adding playlist ${playlist_name} (${playlist_id})"
        curl "https://www.googleapis.com/youtube/v3/playlistItems?part=contentDetails,snippet&playlistId=${playlist_id}&key=${API_KEY}" \
            --header 'Accept: application/json' \
            -fsSL -o ${temp_output_file}

        # Pull playlist data out of response if possible
        if [[ $(jq -r '.pageInfo.totalResults' output.json) == 1 ]]; then
            jq_fields=(
                '.items[0].snippet.title'
                '.items[0].snippet.videoOwnerChannelId'
                '.items[0].snippet.videoOwnerChannelTitle'
                '.pageInfo.totalResults'
                '.items[0].contentDetails.videoPublishedAt'
            )
            {
                read -r playlist_title
                read -r channel_id
                read -r channel_title
                read -r video_count
                read -r first_video
            } < <(IFS=','; jq -r "${jq_fields[*]}" < ${temp_output_file})

            video_count=$(numfmt --to=si "${video_count}" | tr G B)
            echo "Added ${playlist_title} by ${channel_title}: ${video_count} videos"
            output="${output}| ${emoji}[${playlist_title}](https://www.youtube.com/playlist?list=${playlist_id}) | [${channel_title}](https://www.youtube.com/${channel_id}) | ${video_count} | ${first_video} |\n"
        else
            echo "Failed! Bad response received: $(<${temp_output_file})"
            exit 1
        fi
    fi
done < ${playlists_file}

# Replace placeholder in template with output, updating the README
template_contents=$(<${template_file})
echo -e "${template_contents//${placeholder_text}/${output}}" > ${output_file}

# Debug
cat "${WORKSPACE}/README.md"
