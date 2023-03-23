#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Upload markdown images to S3
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📝
# @raycast.argument1 { "type": "text", "placeholder": "/path/to/markdown/file.md" }

# Documentation:
# @raycast.author Robert Cooper
# @raycast.authorURL https://github.com/robertcoopercode

# Easy way to copy file path from Finder:

# 1. Navigate to the file or folder you wish to copy the path for
# 2. Right-click (or Control+Click, or a Two-Finger click on trackpads) on the file or folder in the Mac Finder
# 3. While in the right-click menu, hold down the OPTION key to reveal the “Copy (item name) as Pathname” option, it replaces the standard Copy option

# Set the locale so that the perl command doesn't throw a warning
export LC_ALL=en_US.UTF-8

# Name of corresponding markdown file
md_filename=$(basename "$1" .md)

# Get the directory path of the markdown file
image_dir=$(dirname "$1")/$md_filename

# Read the contents of the markdown file into a variable
md_contents=$(cat "$1")

# Loop through the image links in the array
# Set the DigitalOcean bucket name
bucket_name="basedash-blog"

# Set the region for the DigitalOcean bucket
region="us-east-1"

# Set the AWS access key and secret key
aws_access_key="REPLACE_ME"
aws_secret="REPLACE_ME"

# Function to encode the image filename
urlencode() {
  # Call the uri_escape function from the URI::Escape module
  perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1"
}

# Declare an image_links variable as an indexed array. Note that bash v3 is shipped with
# MacOS, so we can't use associative arrays (bash v4+)
declare -a image_links

# Loop through each image in the directory
for image_path in "$image_dir"/*
do
    index=$(( i + 1 ))
    # Get the image filename
    image_filename=$(basename "$image_path")

    encoded_image_filename=$(urlencode "$image_filename")

    encoded_image_filepath=$(urlencode "$md_filename")/$encoded_image_filename
    # encoded_image_filepath=$md_filename/$image_filename

    # Set the content type for the image file
    content_type=$(file -b --mime-type "$image_path")

    # Defines Access-control List (ACL) permissions, such as private or public.
    acl="x-amz-acl:public-read"

    storage_type="x-amz-storage-class:STANDARD"

    date=$(date -R)

    # Set the signature for the curl command
    string="PUT\n\n$content_type\n$date\n$acl\n$storage_type\n/$bucket_name/$encoded_image_filepath"

    signature=$(echo -en "${string}" | openssl sha1 -hmac "$aws_secret" -binary | base64)

    curl -s -X PUT -T "$image_path" \
       -H "Host: $bucket_name.s3.amazonaws.com" \
       -H "Date: $date" \
       -H "Content-Type: $content_type" \
       -H "$storage_type" \
       -H "$acl" \
       -H "Authorization: AWS $aws_access_key:$signature" \
       "https://$bucket_name.s3.amazonaws.com/$encoded_image_filepath"

    # Save the image links in an array
    image_links[$index]="https://$bucket_name.s3.amazonaws.com/$encoded_image_filepath"
done

# Duplicate the markdown file
modified_file_path=$(dirname "$1")"/[MODIFIED]-$md_filename".md
cp "$1" "$modified_file_path"

md_images=($(grep -Eo '\!\[.*\]\(.*\)' <<< "$md_contents" | grep -Eo '\!\[.*\]\(.*\)' | grep -Eo '\(.*\)' | sed 's/[()]//g'))

for image in "${md_images[@]}"
do
    sed -i '' "s|$image|https://$bucket_name.s3.amazonaws.com/$image|g" "$modified_file_path"
    index=$(( index + 1 ))
done

# Print the variable dictionary
echo "Uploaded the following images: ${image_links[@]}"
