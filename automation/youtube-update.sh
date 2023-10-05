#!/bin/bash

playlists_file="${WORKSPACE}/automation/playlists.txt"
template_file="${WORKSPACE}/automation/template.md"
output_file="${WORKSPACE}/README.md"

header_prefix="### "
placeholder_text="dynamic-playlist-data"
temp_output_file="output.json"
max_results=50
output=""

# Convert list of playlists into Markdown tables
while read -r line; do
    if [[ ${line} == ${header_prefix}* ]]; then
        echo "Adding header ${line}"
        output="${output}\n${line}\n\n"
        output="${output}| Series ↕ | Creator ↕ | First video ↕ | Latest video ↕ |\n| --- | --- | --- | --- |\n"
    else
        IFS=';' read -r playlist_id playlist_name emoji <<< "${line}" # Split line by semi-colon
        echo "Adding playlist ${playlist_name} (${playlist_id})"
        curl "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=${max_results}&playlistId=${playlist_id}&key=${API_KEY}" \
            --header 'Accept: application/json' \
            -fsSL -o ${temp_output_file}

        # Pull playlist data out of response if possible
        if [[ $(jq -r '.pageInfo.totalResults' output.json) -gt 0 ]]; then
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

            # Sanitise output
            video_count=$(numfmt --to=si "${video_count}" | tr G B)
            first_video_title=$(echo ${first_video_title} | tr '|' '-')
            latest_video_title=$(echo ${latest_video_title} | tr '|' '-')

            # Handle case where not all videos fetched
            latest_video_disclaimer=''
            if [[ ${video_count} -gt ${max_results} ]]; then
                missed_videos=$((${video_count} - ${max_results}))
                latest_video_disclaimer="*Note: ${missed_videos} later video(s) omitted[^max-videos]*"
            fi

            echo "Added ${playlist_title} by ${channel_title}: ${video_count} videos"
            output="${output}| ${emoji}[${playlist_name}](https://www.youtube.com/playlist?list=${playlist_id}) (${video_count} videos) | [${channel_title}](https://www.youtube.com/channel/${channel_id}) | [${first_video_date:0:10}: ${first_video_title}<br>![](${first_video_img})](https://youtube.com/watch?v=${first_video_id}) | [${latest_video_date:0:10}: ${latest_video_title}<br>![](${latest_video_img})](https://youtube.com/watch?v=${latest_video_id})<br>${latest_video_disclaimer} |\n"
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
