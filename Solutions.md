# Challenge 1

## AWS Buckets Overview - Attempt 1
[Official AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingBucket.html)
* URLs take the format:
  * https://DOC-EXAMPLE-BUCKET.s3.us-west-2.amazonaws.com/photos/puppy.jpg

In our [scope](http://flaws.cloud), "all challenges are subdomains of flaws.cloud." 

So we are looking for something like: 
* \<arbitrary-name\>.s3.us-west-2.amazonaws.com/

Also performed DNS lookup on flaws.cloud to find that it is indeed hosted in us-west-2 region. 

So now we just need a brute-force to try to find the bucket name portion of the URL.

target url:
\<name\>.s3.us-west-2.flaws.cloud

## Solution

I was wrong about the URL format, it's actually:
flaws.cloud.s3.us-west-2.amazonaws.com
http://flaws.cloud.s3.us-west-2.amazonaws.com

This let to an XML page with details about the bucket contents, including:
* hint1.html, hint2.html, and hint3.html files
* robots.txt
* and a secret-dd02c7c.html 
  * This was the goal of level 1 and the link to level 2.

I also learned about the aws-cli, which I installed and tried out.

`aws s3 ls s3://flaws.cloud --no-sign-request --region us-west-2`

# Challenge 2

The purpose of this challenge was to show an old AWS setting that confused admins. 
Instead of opening your S3 access to "Everyone", you chould choose this option:
* Only Authenticated Users

Admins think this means 'only authenticated users from the admin's account,' but this isn't accurate.

It actually means _any authenticated user on the AWS platform_

As such, you need an AWS account, then:
* Go to the IAM service
* Create a user that at least has S3 read only permissions
  * The default AWS S3 read only policy includes the "list" (as in `ls`) permission
* Within that user generate credentials
  * Note: It is not secure to use long-lived credentials like these. 
  * Recommend removing the credentials and the user afterwards. 
  * See this section for SSO and short-lived options:
    * https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-examples
* Back in AWS CLI, use the command `aws configure`
* Add the credntial information as requested
* Then run the following command (assuming the creds are in the new default profile after the last step)
  * `aws s3 --profile default s3://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud --region us-west-2`
    * This will reveal the secret directory.

# Challenge 3

This challenge went back to "Everyone" access. Listing the contents of the directory revealed a `.git` directory. 

`aws s3 ls s3://level3-9afd3927f195e10225021a578e6f78df.flaws.cloud --no-sign-request --region us-west-2`

I started by looking in another `.git` directory that I had locally, and started pulling down files from the server. There is log entry with a commit hash that says something like "Oops, added something I didn't mean to".

What I learned is two things:
1. The `aws s3 sync <bucket> <local-dest>` command will pull down the entire s3 bucket.
2. You can use `git checkout <hash-of-a-commit>` to update your local repo to what it looked like at the time of the commit.
    * This is why it's not secure to just 'commit again' to remove secrets. They need to be purged from the working tree in git.

`aws s3 sync s3://level3-9afd3927f195e10225021a578e6f78df.flaws.cloud . --no-sign-request --region us-west-2`

`git log`

`git checkout f52ec03b227ea6094b04e43f475fb0126edb5a61`

After this, you will find a text file called `access_keys.txt` with some keys in it.

Now what to do with the access keys...

The challenge prompt says that I should find something that will let me list what other buckets are. I need to research this.

I used the command: `aws s3cli list-buckets`, after adding the newly discovered key to my default profile. This worked. 

The guidance from the challenge hints, however, suggests using a second aws cli profile beyond the `default` profile. To do so:
* Use the command `aws configure --profile <profile-name>`
* Follow the prompts, enter the credentials, default region, etc. 

Then, apparently, you can just use the `ls` command to list all buckets - as long as you don't list a bucket name to `ls` its contents, it will `ls` all buckets.

### Guidance
* Always revoke (delete) and reissue all secrets that have been exposed - don't try to cover it up
* If you give an account the ability to list buckets, they will always be able to list all buckets. 
  * They may be restricted from seeing the contents of certain buckets, but they will still be able to see the existence of buckets.
* S3 bucket names must globally unique across _all of AWS_. 
  * This means that if you use bucket names that reveal sensitive info, someone can find out that the bucket exists since the name will not be available. 
    * E.g. Company_A_merger_with_B  

# Challenge 4

I was off on this one. Had to go for a hint.

They first recommended to use the CLI Secure Token Service to get the account name and ARN:
* `aws --profile flaws sts get-caller-identity`
  * Returns ARN: arn:aws:iam::975426262029:user/backup
* I also found that I can use the following command to generate a short-lived token for the account:
  * `aws --profile flaws sts get-session-token`

The reason you need the ARN/account ID is because there are soooo many public snapshots available to list, and we need to find just the one that is from this org. Use this command:
* `aws --profile flaws ec2 describe-snapshots --owner-id 975426262029`
  * This produces a single snapshot: snap-0b49342abd1bdcb89

Now, how to open and access this.

I couldn't figure it out. They gave this command to create a new volume that contains the snapshot, using the `ec2` subcommand.
`aws --profile YOUR_ACCOUNT ec2 create-volume --availability-zone us-west-2a --region us-west-2  --snapshot-id  snap-0b49342abd1bdcb89`

Then apparently, there isn't any way to create an EC2 from the CLI. So you would need to create an EC2 instance, mount the volume with the snapshot, then `ssh` into the EC2 to view the snapshot data.

I struggled a bit with gettting the snapshot volume to mount to the EC2 instance. This was because I couldn't figure out a "valid device name". I wanted to challenge myself to use the CLI to mount the volume, though I had to use the web console to figure out a valid device name.
* This resource almost had me there:
  * https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html
`aws --profile level4 ec2 attach-volume --device /dev/sdf --instance-id i-0f9411a1048bd2d15 --volume-id vol-05ad33104850539dd`

Once I got into the file system of the snapshot, I found a shell script in the only user's home directory that had a username and password in it. Recalling from the original objective of this level, I used the password to gain access to the target web page that is protected by HTTP Basic Access Authentication (that pop-up style username and password prompt in the browser). The authenticated page listed the URL to the next level!

### Guidance
Be careful with snapshots. If an attacker can access a snapshot, they can attach it to their own EC2 and gain access to your file system through the snapshot. Similarly, if an attacker can access the snapshot controls of an EC2, they can make a copy of the file system and exfiltrate it.


# Challenge 5
Link to Level5: 
- http://level5-d2891f604d2061b6977c2481b0c8333e.flaws.cloud/243f422c/

This challenge is about the IMDS metadata service. 

The goal of this challenge is to find the URL to the start of the level 6 challenge. The URL to the level 6 S3 bucket is given, but the start of level 6 is a particular folder within the level 6 bucket that we don't know. We need to find a way to list the contents of the level 6 bucket to pass level 5 and find the start of level 6. 

You are given a proxy connection on EC2 instance that works like:
- http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/flaws.cloud/
- http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/summitroute.com/blog/feed.xml
- http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/neverssl.com/ 

Anything after "proxy" in the URL path is interpreted as the proxy destination. 

Knowing this, you are able to access the IMDS metadata service on the EC2. It appears to have IMDSv1 enabled, which is not authenticated.
- http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/169.254.169.254/latest/meta-data/iam/security-credentials/flaws

From here, you can explore the various metadata fields before locating some AWS IAM credentials:
- http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/169.254.169.254/latest/meta-data/iam/security-credentials/flaws

The problem with these credentials is that they are temporary and are associated with a token. So, your `~/.aws/credentials/` file needs to include the access key ID, the access key itself, and the temporary session token.

These can be added to the `~/.aws/credentials/` file manually, or can be set using the `aws configure` command:
``` bash
aws configure --profile flaws-level-5
aws configure set aws_session_token <token> --profile flaws-level-5
```

At the end, your `~/.aws/credentials/` file should look like:
```
[flaws-level-5]
aws_access_key_id = ASIA<key-id>
aws_secret_access_key = <key-value>
aws_session_token = <base64-encoded-session-token>
```

With this access key configured within an `aws` CLI profile, you can now check whether you have access to list the contents of the Level 6 bucket, thus locating the start of level 6 and completing challenge 5.

## Guidance

The guidance for this section is that the IMDS metadata service can be a double-edged sword. It allows various cloud resources across various cloud providers to query themselves to access details about their deployment and configuration in the environment. If we're not careful though, this sensitive information can be made available to attackers as well.

For any application, never allow access to local files or IP ranges - this inludes the metadata service on 169.254.169.254. We would never want users of our application to be able to enumerate our internal configs. This can be done with AWS Security Groups and sound application design that follows security best practices.

Additionally, require the use of IMDSv2 which requires authentication to access the metadata. By default, both IMDSv1 and IMDSv2 are allowed, so make sure and restrict the use of IMDSv2.

Also, make sure your applications don't depend on any logic that trusts or relies on `X-Forwarded-For` headers. IMDSv2 automatically denies requests to the metadata service that include this header. 

Finally, and in general, restrict IAM roles and users to the least amount of permissions as possible. I.e. always implement around the least-privilege principle.

# Challenge 6 
Start of level 6:
- http://level6-cc4c404a8a8b876167f5e70a7d8c9880.flaws.cloud/ddcc78ff/

In level 6 you are given an IAM access key, and told that it has been granted the SecurityAudit policy. The SecurityAudit policy allows read-only access to many of AWS' services and resources. It's generally used for security monitoring of an environment, or by audit personnel.

Establish an `aws` CLI profile with the access key to list S3 buckets for the account and immediately finda bucket named: `theend-...[stripped]...flaws.cloud`. Navigating to the bucket though informs you that you need to list and navigate to, again, another sub-directory within this bucket to complete the challenge.

[pause until next time]