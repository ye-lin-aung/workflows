require "test_helper"
require "aws-sdk-s3"

class Workflows::MinioClientTest < ActiveSupport::TestCase
  def build_client(stubbed_responses: {})
    s3_stub = Aws::S3::Client.new(stub_responses: true)
    stubbed_responses.each { |op, resp| s3_stub.stub_responses(op, resp) }

    client = Workflows::MinioClient.new(
      endpoint: "http://fake",
      access_key: "k",
      secret_key: "s",
      bucket: "test-bucket"
    )
    client.instance_variable_set(:@s3, s3_stub)
    client
  end

  test "exists? returns true when head_object succeeds" do
    c = build_client(stubbed_responses: { head_object: {} })
    assert c.exists?("foo/bar.mp4")
  end

  test "exists? returns false on NotFound" do
    c = build_client(stubbed_responses: { head_object: "NotFound" })
    refute c.exists?("missing/key.mp4")
  end

  test "upload calls put_object with the expected args" do
    c = build_client
    s3 = c.instance_variable_get(:@s3)
    s3.stub_responses(:put_object, {})

    Tempfile.create(["hello", ".bin"]) do |f|
      f.write("payload")
      f.close
      c.upload(key: "lms/main/sha/teacher-x-en.mp4", path: f.path, content_type: "video/mp4")
    end

    req = s3.api_requests.last
    assert_equal :put_object, req[:operation_name]
    assert_equal "test-bucket", req[:params][:bucket]
    assert_equal "lms/main/sha/teacher-x-en.mp4", req[:params][:key]
    assert_equal "video/mp4", req[:params][:content_type]
    assert_equal "payload", req[:params][:body]
  end

  test "signed_url returns a presigned URL string" do
    c = build_client
    url = c.signed_url("lms/current/x-en.mp4", expires_in: 60)
    assert_match %r{\Ahttp://fake/test-bucket/lms/current/x-en.mp4}, url
    assert_match(/X-Amz-Signature=/, url)
  end

  test "delete calls delete_object with key" do
    c = build_client
    s3 = c.instance_variable_get(:@s3)
    s3.stub_responses(:delete_object, {})
    c.delete("lms/prs/1/sha/x.mp4")
    req = s3.api_requests.last
    assert_equal :delete_object, req[:operation_name]
    assert_equal "lms/prs/1/sha/x.mp4", req[:params][:key]
  end

  test "s3 client is initialized with path-style addressing for MinIO" do
    client = Workflows::MinioClient.new(
      endpoint: "http://localhost:9000",
      access_key: "k", secret_key: "s", bucket: "b"
    )
    s3 = client.instance_variable_get(:@s3)
    assert s3.config.force_path_style, "expected force_path_style: true for MinIO compatibility"
  end
end
