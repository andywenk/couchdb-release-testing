#!/usr/bin/env ruby

=begin
Small program to delete multiple files on a swing.

Copyright [2019] [Andy Wenk]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=end

# simple helper tool, to follow the testing advices for a new
# couchdb release
#
# URL format:
# https://dist.apache.org/repos/dist/dev/couchdb/source/VERSION/CANDIDATE/apache-couchdb-VERSION.tar.gz

require 'pathname'
require 'uri'
require 'fileutils'
require 'mkmf'

COUCHDB_RELEASE_BASE_URL = 'https://dist.apache.org/repos/dist/dev/couchdb/source/'

def line
    puts
    puts '~~~~~~~~~~~~~~~~~~~ Apache CouchDB release testing ~~~~~~~~~~~~~~~~~~~'
    puts
end

line

puts
puts 'remember: you need to have installed these programms:'
puts 'autoconf autoconf-archive automake libtool erlang icu4c spidermonkey curl pkg-config'
puts
puts 'The release testing info page can be found at:'
puts 'https://cwiki.apache.org/confluence/display/COUCHDB/Testing+a+Source+Release'
puts

line

# check erlang
puts "checking if erlang is installed"
unless find_executable 'erl'
    puts 'Erlang is not installed!'
    exit(0)
end
puts "Erlang is installed"

print 'Provide the couchdb release version: '
release_version     = "#{gets.chomp}"

print 'Provide the couchdb release candidate: '
release_candidate       = "/#{gets.chomp}"

release_candiate_string = release_candidate.upcase.gsub(/[.\/]/,'')
release_file            = "/apache-couchdb-#{release_version}-#{release_candiate_string}.tar.gz"
release_file_url        = URI::parse([COUCHDB_RELEASE_BASE_URL, release_version, release_candidate, release_file].join)

line

# delete old tmp folders
tmp_couchdb_dir = Pathname.new("/tmp/couchdb")
if Dir.exists?(tmp_couchdb_dir)
    FileUtils.rm_rf(tmp_couchdb_dir)
    puts "old directory #{tmp_couchdb_dir} deleted"
end

line

# create new tmp directory and change into it
tmp_dist_directory  = Pathname.new("/tmp/couchdb/dist")
tmp_git_directory   = Pathname.new("/tmp/couchdb/git")
tmp_tree_directory  = Pathname.new("/tmp/couchdb/tree")

FileUtils.mkdir_p(tmp_dist_directory)
FileUtils.mkdir_p(tmp_git_directory)
FileUtils.mkdir_p(tmp_tree_directory)

# change t0 dist directory 
Dir.chdir(tmp_dist_directory)
puts "created directory dist, git, tree and changed into #{tmp_dist_directory}"

line

# check if wget is available
puts 'checking if wget is installed'
unless find_executable 'wget'
    puts 'wget is not installed. Aborting. Pleas install wget'
    exit(0)
end

line

# download the needed files
puts "download the release files"
`wget #{release_file_url} > /dev/null`
`wget "#{release_file_url}.asc" > /dev/null`
`wget "#{release_file_url}.sha256" > /dev/null`
`wget "#{release_file_url}.sha512" > /dev/null`

puts "downloaded couchdb release files successfully:"
Dir.foreach(Pathname.new(Dir.pwd)) { |file| puts file }

line

# check if PGP is available
puts 'checking if pgp is installed'
unless find_executable 'gpg'
    puts 'gpg is not installed.'
    exit(0)
end

line

# install gpg keys for couchdb
puts 'import gpg keys for couchdb'
if system("curl https://apache.org/dist/couchdb/KEYS | gpg --import - > /dev/null")
    puts "pgp keys for couchdb imported" 
else
    puts "pgp keys for couchdb not imported" 
    exit(0)
end

line

# verify the signature of the release file
puts 'verify the signature of the release file'
puts `gpg --verify apache-couchdb-*.tar.gz.asc`

line

# check if sha256 sum is available
puts 'checking if pgp is installed'
unless find_executable 'sha256sum'
    puts 'pgp is not installed. Aborting. Pleas install coreutils'
    puts 'on Mac with: brew install coreutils'
    puts 
    puts 'Afterwards, you may need to also do this:'
    puts 'sudo ln -s /usr/local/bin/gsha256sum /usr/local/bin/sha256sum'
    puts 'sudo ln -s /usr/local/bin/gsha512sum /usr/local/bin/sha512sum'
    exit(0)
end

line

# check sha256sum
puts 'checking sha256 sum'
sha256sum_result = system("sha256sum apache-couchdb-#{release_version}-#{release_candiate_string}.tar.gz.sha256 > /dev/null")
unless sha256sum_result
    puts 'the sha256sum is incorrect'
    exit(0)
else
    puts 'the sha256sum is correct'
end

line

# check sha512sum
puts 'checking sha512 sum'
sha512sum_result = system("sha512sum apache-couchdb-#{release_version}-#{release_candiate_string}.tar.gz.sha512 > /dev/null")
unless sha512sum_result
    puts 'the sha512sum is incorrect'
    exit(0)
else
    puts 'the sha512sum is correct'
end

line

# make a pristine copy from the tree-ish.  
puts 'Make a pristine copy from the tree-ish'
git_clone_tree_ish_result = system("git clone https://git-wip-us.apache.org/repos/asf/couchdb.git #{tmp_git_directory} > /dev/null")
unless git_clone_tree_ish_result
    puts 'git clone of CouchDB did not succeed'
    exit(0)
else
    Dir.chdir(tmp_git_directory)
    puts 'git clone of CouchDB finished and cd\'ed into it'
end

line 

# make a git archive
puts "use git archive to create the tree-ish"
git_archive_result = system("git archive --prefix=/tmp/couchdb/tree/ `cat /tmp/couchdb/dist/apache-couchdb-#{release_version }-#{release_candiate_string}.tar.gz.ish` | tar -Pxf - > /dev/null")
unless git_archive_result
    puts 'git archive did not succeed'
    exit(0)
else
    Dir.chdir(tmp_dist_directory)
    puts 'git archive finished and cd\'ed into it'
end

line 

# unpack teh tarball
puts "unpacking the tarball"
unpack_tarball_result = system("tar -xvzf apache-couchdb-#{release_version }-#{release_candiate_string}.tar.gz")
unless unpack_tarball_result
    puts 'unpacking tarball did not succeed'
    exit(0)
else
    puts 'unpacking tarball finished'
end

line 

# make a diff to tree
diff_result = system("diff -r apache-couchdb-#{release_version} ../tree")
puts 'diff finished'

line

# Test the code
puts "Test the code. First cd into the release version directory"
Dir.chdir(tmp_dist_directory)
Dir.chdir("apache-couchdb-#{release_version}")
puts "Changed into #{Dir.pwd}" 

# run configure
puts "run configure"
configure_result = system("./configure -c")
unless configure_result
    puts 'configure did not succeed'
    exit(0)
else
    puts 'running configure finished'
end

line 

# run make check
puts "run make check"
system("make check")

line 

# run make release
puts "run make release"
system("make release")

line

puts "you now have to setup a admin user / password in /tmp/couchdb/dist/apache-couchdb-#{release_version}/rel/couchdb/etc/local.ini"
puts "if done, you can start CouchDB with: /tmp/couchdb/dist/apache-couchdb-#{release_version}/rel/couchdb/bin/couchdb"

line
puts "That's it. Bye!"
line
