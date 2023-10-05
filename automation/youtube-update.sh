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
        output="${output}| Ironman ↕ | Creator ↕ | First video ↕ | Latest video ↕ |\n| --- | --- | --- | --- |\n"
    else
        IFS=';' read -r playlist_id playlist_name emoji <<< "${line}" # Split line by semi-colon
        echo "Adding playlist ${playlist_name} (${playlist_id})"
        curl "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=${playlist_id}&key=${API_KEY}" \
            --header 'Accept: application/json' \
            -fsSL -o ${temp_output_file}

        # Pull playlist data out of response if possible
        if [[ $(jq -r '.pageInfo.totalResults' output.json) > 0 ]]; then
            jq_fields=(
                '.pageInfo.totalResults'
                '.items[0].snippet.videoOwnerChannelId'
                '.items[0].snippet.videoOwnerChannelTitle'
                '.items[0].snippet.resourceId.videoId'
                '.items[0].snippet.title'
                '.items[0].snippet.publishedAt'
                '.items[0].snippet.thumbnails.medium.url'
                '.items[-1].snippet.resourceId.videoId'
                '.items[-1].snippet.title'
                '.items[-1].snippet.publishedAt'
                '.items[-1].snippet.thumbnails.medium.url'
            )
            {
                read -r video_count
                read -r channel_id
                read -r channel_title
                read -r first_video_id
                read -r first_video_title
                read -r first_video_date
                read -r first_video_img
                read -r latest_video_id
                read -r latest_video_title
                read -r latest_video_date
                read -r latest_video_img
            } < <(IFS=','; jq -r "${jq_fields[*]}" < ${temp_output_file})

            video_count=$(numfmt --to=si "${video_count}" | tr G B)
            playlist_title=$(echo ${playlist_title} | tr '|' '&#124;')
            echo "Added ${playlist_title} by ${channel_title}: ${video_count} videos"
            output="${output}| ${emoji}[${playlist_name}](https://www.youtube.com/playlist?list=${playlist_id}) (${video_count} videos) | [${channel_title}](https://www.youtube.com/channel/${channel_id}) | [${first_video_date:0:10}: ${first_video_title}\n![](${first_video_img})](https://youtube.com/watch?v=${first_video_id}) | [${latest_video_date:0:10}: ${latest_video_title}\n![](${latest_video_img})](https://youtube.com/watch?v=${latest_video_id}) |\n"
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
