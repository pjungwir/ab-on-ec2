# This file uses AWS instances to load-test the Example.com staging site.
# You can use it like this:
#   make 2_hosts 100_hits_each
#
# Or you can run the commands separately.
# You only need to run the n_hosts commands once.
#
# When you're done, run rm_hosts to terminate the instances.
# Note that only the most-recently created instanced will get terminated.

# AUTH=staging:secret
# HOSTNAME=staging.example.com
AUTH=example:secret
HOSTNAME=1.2.3.4
AMI=ami-ef6aa486		# Basically any AMI with ab installed.
KEY_FILE=/home/paul/src/example/doc/it/aws/pk-abcd.pem
CERT_FILE=/home/paul/src/example/doc/it/aws/cert-abcd.pem
LOGIN_KEY=/home/paul/src/example/doc/it/aws/example.pem
TARGET_URL=http://${HOSTNAME}/questions/next

prep:
	mkdir -p results

2_hosts: launch_2_hosts get_domain_names

5_hosts: launch_5_hosts get_domain_names

10_hosts: launch_10_hosts get_domain_names

17_hosts: launch_17_hosts get_domain_names

rm_hosts:
	ec2-terminate-instances -K ${KEY_FILE} -C ${CERT_FILE} `cat instance-names`

launch_2_hosts:
	ec2-run-instances -K ${KEY_FILE} -C ${CERT_FILE} ${AMI} -n 2 -t m1.large -z us-east-1a -k example -g quick-start-1 | grep '^INSTANCE' | awk '{ print $$2 }' | tee instance-names

launch_5_hosts:
	ec2-run-instances -K ${KEY_FILE} -C ${CERT_FILE} ${AMI} -n 5 -t m1.large -z us-east-1a -k example -g quick-start-1 | grep '^INSTANCE' | awk '{ print $$2 }' | tee instance-names

launch_10_hosts:
	ec2-run-instances -K ${KEY_FILE} -C ${CERT_FILE} ${AMI} -n 10 -t m1.large -z us-east-1a -k example -g quick-start-1 | grep '^INSTANCE' | awk '{ print $$2 }' | tee instance-names

launch_17_hosts:
	ec2-run-instances -K ${KEY_FILE} -C ${CERT_FILE} ${AMI} -n 17 -t m1.large -z us-east-1a -k example -g quick-start-1 | grep '^INSTANCE' | awk '{ print $$2 }' | tee instance-names

get_domain_names:
	# ec2-describe-instances writes "pending" as the domain name for the first few seconds after launch,
	# so we need to keep trying until we know all the domain names:
	echo "pending" > domain-names
	while grep pending domain-names >/dev/null; do \
		sleep 1; \
		echo 'trying to get domain names...'; \
	  cat instance-names | xargs -i{} ec2-describe-instances {} | grep '^INSTANCE' | awk '{ print $$4 }' | tee domain-names; \
	done

1000_hits_each: clean prep
	# Arg!: parallel-ssh doesn't support `-i key-file`. So we do our own clumsy implementation.
	# We also have to use UserKnownHostsFile and StrictHostKeyChecking
	# to avoid ssh pausing to ask us to verify the hostname.
	for h in `cat domain-names`; do \
	  echo $$h; \
		ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${LOGIN_KEY} ec2-user@$$h "ab -A '${AUTH}' -c 2 -n 1000 ${TARGET_URL}" >results/$$h 2>&1 & \
	done; \
	wait
	# parallel-ssh -v -P -l ec2-user -O '-i ${LOGIN_KEY}' -h domain-names -o results hostname
	# parallel-ssh -v -P -l ec2-user -p 30 -t -1 -h domain-names -o results "ab -A '${AUTH}' -c 1 -n 5 http://${HOSTNAME}/"

100_hits_each: prep
	# parallel-ssh -p 30 -t -1 -h domain-names -o results "ab -A '${AUTH}' -c 1 -n 100 http://${HOSTNAME}/"
	# pssh 'ab -A ${AUTH} -c 1 -n 100 http://${HOSTNAME}/ > ab-result-`hostname` &' -h domain-names -o results
	for h in `cat domain-names`; do \
	  echo $$h; \
		ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${LOGIN_KEY} ec2-user@$$h "ab -A '${AUTH}' -c 1 -n 100 ${TARGET_URL}" >results/$$h 2>&1 & \
	done; \
	wait

clean:
	rm -rf results
