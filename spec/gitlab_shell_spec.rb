require_relative 'spec_helper'
require_relative '../lib/gitlab_shell'

describe GitlabShell do
  subject do
    ARGV[0] = key_id
    GitlabShell.new.tap do |shell|
      shell.stub(exec_cmd: :exec_called)
      shell.stub(api: api)
    end
  end
  let(:api) do
    double(GitlabNet).tap do |api|
      api.stub(discover: 'John Doe')
      api.stub(allowed?: true)
    end
  end
  let(:key_id) { "key-#{rand(100) + 100}" }
  let(:repository_path) { "/home/git#{rand(100)}/repos" }
  before { GitlabConfig.any_instance.stub(:repos_path).and_return(repository_path) }

  describe :initialize do
    before { ssh_cmd 'git-receive-pack' }

    its(:key_id) { should == key_id }
    its(:repos_path) { should == repository_path }
  end

  describe :parse_cmd do
    context 'w/o namespace' do
      before do
        ssh_cmd 'git-upload-pack gitlab-ci.git'
        subject.send :parse_cmd
      end

      its(:repo_name) { should == 'gitlab-ci.git' }
      its(:git_cmd) { should == 'git-upload-pack' }
    end

    context 'namespace' do
      before do
        ssh_cmd 'git-upload-pack dmitriy.zaporozhets/gitlab-ci.git'
        subject.send :parse_cmd
      end

      its(:repo_name) { should == 'dmitriy.zaporozhets/gitlab-ci.git' }
      its(:git_cmd) { should == 'git-upload-pack' }
    end
  end

  describe :exec do
    context 'git-upload-pack' do
      before { ssh_cmd 'git-upload-pack gitlab-ci.git' }
      after { subject.exec }

      it "should process the command" do
        subject.should_receive(:process_cmd).with()
      end

      it "should execute the command" do
        subject.should_receive(:exec_cmd).with("git-upload-pack #{File.join(repository_path, 'gitlab-ci.git')}")
      end

      it "should set the GL_ID environment variable" do
        ENV.should_receive("[]=").with("GL_ID", key_id)
      end
    end

    context 'git-receive-pack' do
      before { ssh_cmd 'git-receive-pack gitlab-ci.git' }
      after { subject.exec }

      it "should process the command" do
        subject.should_receive(:process_cmd).with()
      end

      it "should execute the command" do
        subject.should_receive(:exec_cmd).with("git-receive-pack #{File.join(repository_path, 'gitlab-ci.git')}")
      end
    end

    context 'arbitrary command' do
      before { ssh_cmd 'arbitrary command' }
      after { subject.exec }

      it "should not process the command" do
        subject.should_not_receive(:process_cmd)
      end

      it "should not execute the command" do
        subject.should_not_receive(:exec_cmd)
      end
    end

    context 'no command' do
      before { ssh_cmd nil }
      after { subject.exec }

      it "should call api.discover" do
        api.should_receive(:discover).with(key_id)
      end
    end
  end

  describe :validate_access do
    before { ssh_cmd 'git-upload-pack gitlab-ci.git' }
    after { subject.exec }

    it "should call api.allowed?" do
      api.should_receive(:allowed?).
        with('git-upload-pack', 'gitlab-ci.git', key_id, '_any')
    end
  end

  def ssh_cmd(cmd)
    ENV['SSH_ORIGINAL_COMMAND'] = cmd
  end

end
