require "aws-sdk-s3"

module Workflows
  # Thin wrapper around Aws::S3::Client configured for MinIO. Kept narrow
  # (upload / exists? / signed_url / delete) so the Publisher and Catalog
  # can be tested by stubbing just these four methods.
  class MinioClient
    def initialize(endpoint:, access_key:, secret_key:, bucket:, region: "us-east-1")
      @bucket = bucket
      @s3 = Aws::S3::Client.new(
        endpoint: endpoint,
        access_key_id: access_key,
        secret_access_key: secret_key,
        force_path_style: true,
        region: region
      )
      # Held separately so presigned URLs keep the configured MinIO endpoint
      # even when tests stub @s3 with a bare Aws::S3::Client(stub_responses: true).
      @presigner = Aws::S3::Presigner.new(client: @s3)
    end

    def upload(key:, path:, content_type:)
      @s3.put_object(
        bucket: @bucket,
        key: key,
        body: File.read(path),
        content_type: content_type
      )
    end

    def exists?(key)
      @s3.head_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end

    def signed_url(key, expires_in:)
      @presigner.presigned_url(
        :get_object,
        bucket: @bucket,
        key: key,
        expires_in: expires_in.to_i
      )
    end

    def delete(key)
      @s3.delete_object(bucket: @bucket, key: key)
    end
  end
end
