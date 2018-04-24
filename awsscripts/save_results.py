import csv
import time
import sys
import cloud_setup
import os


def save_results(job, tag):
    try:
        # current_time = time.time()
        # key = "%s-%s-%f" % (job, tag, current_time)

        # Create S3 bucket
        s3, bucket = cloud_setup.setup_s3_bucket(job)

        # Add all files in output/ to bucket
        for filename in os.listdir("../output"):
            cloud_setup.add_file_to_s3_bucket(bucket, tag, os.path.join("../output", filename))

        # Self-terminate at completion
        cloud_setup.terminate_instance(tag)
    except:
        cloud_setup.add_tag(tag, "dataset", "finished")


if __name__ == "__main__":
    # Validate command-line arguments
    if len(sys.argv) < 3:
        print "Usage: python2 save_results.py job tag"
        exit(1)

    save_results(sys.argv[1], sys.argv[2])
