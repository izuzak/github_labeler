RSpec.describe GitHubLabeler do
  describe "construction" do
    let(:labeler) { GitHubLabeler.new(token) }

    context "with a valid token" do
      let(:token) { "1234567890abcdef1234567890abcdef12345678" }

      before do
        allow_any_instance_of(Octokit::Client).to receive(:rate_limit).and_return(5000)
      end

      it "initializes the logger" do
        expect(labeler.logger).to be_a(Logger)
      end

      it "sets the repo_labels to empty" do
        expect(labeler.repo_labels).to eq({})
      end
    end

    context "with an invalid token" do
      let(:token) { "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" }

      before do
        allow_any_instance_of(Logger).to receive(:error)
        allow_any_instance_of(Octokit::Client).to receive(:rate_limit).and_raise(Octokit::Unauthorized)
      end

      it "raises an ArgumentError" do
        expect { labeler }.to raise_error(ArgumentError)
      end
    end
  end
end
