aws batch list-jobs --job-queue routing-queue --job-status FAILED | jq .jobName | tr -d '"' | tr -d 'otp-'
