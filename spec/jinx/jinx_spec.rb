require 'tmpdir'
load "scripts/jinx.lic"

$fake_game_output = ""

def _respond(*args)
  $fake_game_output = $fake_game_output + "\n" + args.join("\n")
end

def game_output
  buffered = $fake_game_output.dup
  $fake_game_output = ""
  return buffered
end

module Jinx
  describe Setup do
    it "bails when $data_dir doesn't exist" do
      expect {Setup.apply}.to raise_error(Jinx::Error, "$data_dir is not String")
    end

    it "creates the $data_dir/_jinx folder" do
      $data_dir = Dir.mktmpdir()
      Setup.apply
      Repo.lookup("core")
      Repo.lookup("elanthia-online")
    end
  end

  describe Service do
    before(:each) do
      $data_dir =  Dir.mktmpdir("data")
      $script_dir = Dir.mktmpdir("scripts")
      Setup.apply
      game_output
    end
    
    it "repo list" do
      Service.run("repo list")
      output = game_output
      expect(output).to include("core:")
      expect(output).to include("elanthia-online:")
    end

    it "(core) repo info" do
      Service.run("repo info core")
      output = game_output
      expect(output).to include("scripts:")
      expect(output).to include("go2.lic")
      expect(output).to include("infomon.lic")
    end

    it "(core) script install" do
      # will install the first time cleanly on 1-to-1
      Service.run("script install go2")
      _first_attempt = game_output
      local_script = File.join($script_dir, "go2.lic")
      expect(File.exist?(local_script)).to be true
      # will not accidentally overwrite already existing script
      expect {Service.run("script install go2")}
        .to raise_error(Jinx::Error, /go2.lic already exists/)
      _second_attempt = game_output # clear
    end

    it "(core) script update" do
      Service.run("script update go2")
    end

    it "repo add" do
      Service.run("repo add archive https://archive.lich.elanthia.online")
      Repo.lookup("archive")
      # specificity is required
      expect {Service.run("script install go2")}
        .to raise_error(Jinx::Error, /more than one repo has/)

      # make a clean script dir
      $script_dir = Dir.mktmpdir("scripts")
      # ensure installing go2 from this archive works
      game_output # clear
      Service.run("script install go2 --repo=archive")
      installed_file = File.join($script_dir, "go2.lic")
      expect(File.exist?(installed_file)).to be true
      install_output = game_output
      expect(install_output).to include("installing go2.lic from repo:archive")
      expect {Service.run("script install go2 --repo=archive")}
        .to raise_error(Jinx::Error, /go2.lic already exists/)
      game_output # clear
      Service.run("script update go2 --repo=archive")
      update_output = game_output
      expect(update_output).to include("installing go2.lic from repo:archive")
    end

    it "script info" do
      Service.run("script info noop")
      info_output = game_output
      expect(info_output).to include("noop (repo: elanthia-online, modified:")
      Service.run("repo add archive https://archive.lich.elanthia.online")
      # now two repos advertise noop, so it should error
      expect {Service.run("script info noop")}
        .to raise_error(Jinx::Error, 
          %r[more than one repo has script\(noop.lic\)])

      expect {Service.run("script info noop --repo=core")}
        .to raise_error(Jinx::Error, 
          %r[repo\(core\) does not advertise script\(noop.lic\)])
      game_output # clear
      # make sure it checks the elanthia-online repo
      Service.run("script info noop --repo=elanthia-online")
      info_output = game_output
      expect(info_output).to include("noop (repo: elanthia-online, modified:")
      # make sure it checks the archive repo
      Service.run("script info noop --repo=archive")
      info_output = game_output
      expect(info_output).to include("noop (repo: archive, modified:")
    end

    it "script search" do
      Service.run("script search noop")
      search_output = game_output
      expect(search_output).to include("found 1 match")
      Service.run("script search asdfasdfjahksdkfajsdhfka")
      search_output = game_output
      expect(search_output).to include("found 0 matches")
      Service.run("script search noop")
      search_output = game_output
      expect(search_output).to include("found 1 match")
      Service.run("repo add archive https://archive.lich.elanthia.online")
      # regex search
      Service.run("script search ^noop.lic")
      search_output = game_output
      expect(search_output).to include("found 2 matches")
      # repo specific search
      Service.run("script search ^noop.lic --repo=archive")
      search_output = game_output
      expect(search_output).to include("found 1 match")
      expect(search_output).to include("archive>")
    end
  end
end
