#!/bin/bash
# Attempts to attach ENI to an EC2 instance, the way it attaches is via
# tags in the ENI. If you ENI is in the same availability zone and is "available" and has the same
# stack name tag then you are cool to take the ENI
#
# Policy Statement:
#    {
#        "Effect": "Allow",
#        "Action": [
#            "ec2:AssociateAddress",
#            "ec2:AssignPrivateIpAddresses",
#            "ec2:AttachNetworkInterface",
#            "ec2:CreateNetworkInterface",
#            "ec2:DescribeInstances",
#            "ec2:DescribeNetworkInterfaces",
#            "ec2:DetachNetworkInterface"
#        ],
#        "Resource": [
#            "*"
#        ]
#    }
#
# Uncomment for debugging
#set -x

# TODO: Make use the one provided in nubis-base
# Common functions.
. /usr/local/lib/util.sh

function _get_eni_id {

    if [ -z "$1" ] && [ -z "$2" ]; then echo "Usage: ${FUNCNAME} [region] [stackname]"; return 1; fi

    local availability_zone=$(curl -s -fq http://169.254.169.254/latest/meta-data/placement/availability-zone)
    local region=$1
    local stack_name=$2

    aws ec2 describe-network-interfaces \
        --region ${region} \
        --filter \
            Name=tag-value,Values=${stack_name}\
            Name=availability-zone,Values=${availability_zone}\
        --query \
            'NetworkInterfaces[?Status == `available`][NetworkInterfaceId]'\
        --output text
}


echo -n "Waiting for instance to come up ... "
aws ec2 wait instance-running --instance-ids ${INSTANCE_ID} --region ${REGION}
echo "Done"

ENI_ID=$(_get_eni_id ${REGION} ${NUBIS_STACK})

if [[ ! -z "${ENI_ID}" ]]; then
    log "Attaching ${ENI_ID} to ${INSTANCE_ID}"
    aws ec2 attach-network-interface --region ${REGION} --network-interface-id ${ENI_ID} --instance-id ${INSTANCE_ID} --device-index 1
else
    # Assuming if it hits here we do not attach
    log "Unable to attach ${ENI_ID} to ${INSTANCE_ID}"
    exit 1
fi
