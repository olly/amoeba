#!/bin/bash -ex

INSTANCE_ID=$( terraform state show aws_instance.amoeba | grep "^id" | awk '{ print $3 }' )

VOLUME_ID=$( aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq --raw-output '.Reservations[].Instances[].BlockDeviceMappings[] | select(.DeviceName == "/dev/sdb") | .Ebs.VolumeId' )
echo "Volume ID: $VOLUME_ID"

BUILD_TIME="$( date -u +%Y-%m-%dT%H:%M:%SZ )"
IMAGE_NAME="amoeba-$( date -u +%Y-%m-%dT%H-%M-%SZ )"
echo "Image Name: $IMAGE_NAME"

SNAPSHOT_ID=$( aws ec2 create-snapshot --volume-id $VOLUME_ID --description "$IMAGE_NAME" | jq --raw-output '.SnapshotId' )
echo "Snapshot ID: $SNAPSHOT_ID"

aws ec2 wait snapshot-completed --snapshot-ids $SNAPSHOT_ID

IMAGE_ID=$( aws ec2 register-image --name "$IMAGE_NAME" --virtualization-type hvm --architecture x86_64 --root-device-name /dev/sda1 \
	--block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\": { \"SnapshotId\": \"$SNAPSHOT_ID\", \"VolumeSize\": 8,  \"DeleteOnTermination\": true, \"VolumeType\": \"gp2\"}}]" \
		| jq --raw-output '.ImageId' )
echo "Image ID: $IMAGE_ID"

aws ec2 wait image-available --image-ids $IMAGE_ID
aws ec2 create-tags --resources $IMAGE_ID --tags "Key=Name,Value=$IMAGE_NAME" "Key=BuildTime,Value=$BUILD_TIME"
