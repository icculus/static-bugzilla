#!/usr/bin/perl -w

# static-bugzilla; a hacky way to make a Bugzilla install a read-only archive.
#
# Please read README.md for how to use this.
#
# Please see the file LICENSE.txt in the source's root directory.
#
#  This file written by Ryan C. Gordon.

use warnings;
use strict;

# EDIT THESE LINES TO FIT YOUR BUGZILLA INSTALL!
my $sitename = 'bugzilla.icculus.org';  # This can also be a real name like "The Icculus Bugtracker" or whatever.
my $total_attachments = 3639;  # the highest attachment id provided by the bugtracker. Set this high until the script fails if you don't know.
my $total_bugs = 6678;  # the highest bug id provided by the bugtracker. Set this high until the script fails if you don't know.
my $bugzilla_url = 'https://bugzilla.icculus.org';  # the base URL for the bugtracker.
my $bugzilla_attachments_url = 'https://bugzilla-attachments.icculus.org';  # the base URL for the bugtracker's attachments, which might be different. Click an attachment and see where it takes you if you don't know.
# EDIT THESE LINES TO FIT YOUR BUGZILLA INSTALL!



if ( ! -f "images/favicon.ico" ) {
    system("mkdir -p 'images'") == 0 or die("Failed to mkdir -p 'images'");
    print("Collecting favicon.ico...\n");
    system("curl -o 'data-in-progress' '$bugzilla_url/images/favicon.ico'") == 0 or die("curl failed on favicon.ico!");
    system("mv 'data-in-progress' 'images/favicon.ico'");
}
print("favicon.ico is collected!\n\n");

print("Collecting attachments...\n");
my $attachmentsdir = 'attachments';
for (my $i = 1; $i <= $total_attachments; $i++) {
    my $dir = "$attachmentsdir/" . int($i / 1000) . '/' . int(($i % 1000) / 100) . '/' . $i;
    next if ( -f "$dir/data" );  # already done with this one.
    print(" - Collecting attachment $i ...\n");
    my @curlhead = split /\r\n/, `curl -I -s -S "$bugzilla_attachments_url/attachment.cgi?id=$i"`;
    die("HTTP HEAD failed on attachment $i") if not @curlhead;    
    die("Unexpected HTTP response '{$curlhead[0]}' on attachment $i") if $curlhead[0] ne 'HTTP/1.1 200 OK';

    my %response = ();
    foreach (@curlhead) {
        if (/\A(.*?)\:\s+(.*)\Z/) {
            $response{$1} = $2;
        }
    }

    system("mkdir -p '$dir'") == 0 or die("Failed to mkdir -p '$dir'");
    open(FH, '>', "$dir/content-disposition") or die("Failed to open '$dir/content-disposition': $!"); print FH $response{'Content-disposition'}; close(FH);
    open(FH, '>', "$dir/content-type") or die("Failed to open '$dir/content-type': $!"); print FH $response{'Content-Type'}; close(FH);
    system("curl -o 'data-in-progress' '$bugzilla_attachments_url/attachment.cgi?id=$i'") == 0 or die("curl failed on attachment $i!");
    system("mv 'data-in-progress' '$dir/data'");
}
print("Attachments are all collected!\n\n");

print("Collecting bug reports...\n");
my $origdir = 'original-bugs-html';
mkdir($origdir) if ( ! -d $origdir );
for (my $i = 1; $i <= $total_bugs; $i++) {
    next if ( -f "$origdir/$i" );  # already done with this one.
    print(" - Collecting bug $i ...\n");
    my $url = "$bugzilla_url/show_bug.cgi?id=$i";
    system("curl -o 'data-in-progress' '$url'") == 0 or die("curl failed on bug $i!");
    system("mv 'data-in-progress' '$origdir/$i'");
}
print("Bug reports are all collected!\n\n");


print("Generating static HTML files...\n\n");
my $finaldir = "bugs-html";
mkdir($finaldir) if ( ! -d $finaldir );
for (my $i = 1; $i <= $total_bugs; $i++) {
    my $dir = "$finaldir/" . int($i / 1000) . '/' . int(($i % 1000) / 100);
    #$dir = "$finaldir";
    next if ( -f "$dir/$i" );  # already done with this one.
    print(" - Generating static HTML for bug $i ...\n");
    system("mkdir -p '$dir'") == 0 or die("Failed to mkdir -p '$dir'");
    open(FHORIGIN, '<', "$origdir/$i") or die("Failed to open '$dir/$i': $!");
    my $bugtitle = undef;
    my $bugcomments = undef;
    my $bugstatus = undef;
    my $product = undef;
    my $classification = undef;
    my $component = undef;
    my $lastmod = undef;
    my $reportedtime = undef;
    my $reportedby = undef;
    my $cclist = undef;
    my $version = undef;
    my $hardware = undef;
    my $importance = undef;
    my $assignee = undef;
    my $qacontact = undef;
    my $alias = undef;
    my $url = undef;
    my $blocks = undef;
    my $dependson = undef;
    my $seealso = undef;
    my $attachments = '';
    my $duplicates = '';

    my $skip_this_bug = 0;

    while (<FHORIGIN>) {
        chomp;
        #print("$_\n");

        $skip_this_bug = 1, last if (/\A\s*<title\>Missing Bug ID\<\/title\>\s*\Z/);

        if (/\A\<table class\=\"bz_comment_table\"\>\Z/) {
            $bugcomments = "$_\n";
            while (<FHORIGIN>) {
                $bugcomments .= $_;
                chomp;
                last if /\A\<\/tr\>\<\/table\>\Z/;
            }
        } elsif (/\A\s*\<span id\=\"information\" class\=\"header_addl_info\"\>Last modified: (.*?)\<\/span\>\Z/) {
            $lastmod = $1;
        } elsif (/\A\s*\<span id\=\"subtitle\" class=\"subheader\"\>(.*?)\<\/span\>\Z/) {
            $bugtitle = $1;
        } elsif (/\A\s*<title\>\d+ \&ndash\; (.*?)\<\/title\>\s*\Z/) {
            $bugtitle = $1;
        } elsif (/\A\s*\<span id\=\"static_bug_status\"\>(.*)\Z/) {
            $bugstatus = $1;
            while (<FHORIGIN>) {
                chomp;
                s/\A\s*//;
                s/\s*\Z//;
                last if $_ eq '</span>';
                $bugstatus .= " $_";
            }
        } elsif (/\A\s*\<span id\=\"blocked_input_area\"\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Blocks parsing") if not $tmp =~ /\A\s*\<\/span\>\s*\Z/;
            $blocks = '';
            while (<FHORIGIN>) {
                chomp;
                last if /\A\s*\<\/td\>\s*\Z/;
                $blocks .= "$_\n";
            }
        } elsif (/\A\s*\<span id\=\"dependson_input_area\"\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Dependson parsing") if not $tmp =~ /\A\s*\<\/span\>\s*\Z/;
            $dependson = '';
            while (<FHORIGIN>) {
                chomp;
                last if /\A\s*\<\/td\>\s*\Z/;
                $dependson .= "$_\n";
            }
        } elsif (/\A\s*\<span id\=\"duplicates\"\>/) {
            my $dupcount = 0;
            my $dups = "$_\n";
            while (<FHORIGIN>) {
                $dups .= $_;
                $dupcount++ if /href\=\"show_bug.cgi\?id=\d+/;
                chomp;
                s/\A\s*//;
                s/\s*\Z//;
                last if $_ eq '</span>';
            }
            $duplicates = "<tr><th class=\"field_label\"><label>Duplicates ($dupcount)</label>:\n</th><td class=\"field_value\">\n$dups</td></tr>";
        } elsif (/\A\s*CC List\:/) {
            my $cc = '';
            while (<FHORIGIN>) {
                if (/\<script/) {
                    while (<FHORIGIN>) {
                        last if /\<\/script\>/;
                    }
                    next;
                }
                s/class\=\"bz_default_hidden\"//g;
                $cc .= $_;
                chomp;
                s/\A\s*//;
                s/\s*\Z//;
                last if $_ eq '</tr>';
            }
            $cclist = "<th class=\"field_label\"><label  accesskey=\"a\">CC List:$cc\n";
        } elsif (/\A\s*\<td\>(.*?) by \<span class\=\"vcard\"\>(.*?)\Z/) {
            $reportedtime = $1;
            $reportedby = $2;
        } elsif (/\A\s*id\=\"field_container_product\" >(.*?)\s*\Z/) {
            $product = $1;
        } elsif (/\A\s*id\=\"field_container_classification\" >(.*?)\s*\Z/) {
            $classification = $1;
        } elsif (/\A\s*id\=\"field_container_component\" >(.*?)\s*\Z/) {
            $component = $1;
        } elsif (/\A\s*\>Version\:\<\/a\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Version parsing") if $tmp ne "\n";
            $tmp = <FHORIGIN>; die("unexpected Version parsing") if $tmp ne "</th>\n";
            $tmp = <FHORIGIN>; die("unexpected Version parsing") if not $tmp =~ s/\A\<td\>//;
            $version = $tmp;
            $tmp = <FHORIGIN>; die("unexpected Version parsing") if $tmp ne "  </td>\n";
        } elsif (/\A\s*\>Hardware\:\<\/a\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Hardware parsing") if $tmp ne "\n";
            $tmp = <FHORIGIN>; die("unexpected Hardware parsing") if $tmp ne "</th>\n";
            $tmp = <FHORIGIN>; die("unexpected Hardware parsing") if not $tmp =~ s/\A\s*\<td class\=\"field_value\"\>//;
            $hardware = $tmp;
            while (<FHORIGIN>) {
                chomp;
                s/\A\s*//;
                s/\s*\Z//;
                last if $_ eq '</td>';
                $hardware .= " $_";
            }
        } elsif (s/\A\s*\<span id\=\"bz_url_input_area\"\>//) {
            $url = $_;
            while (<FHORIGIN>) {
                chomp;
                last if /\A\s*\<\/span\>\Z/;
                $url .= "$_\n";
            }
        } elsif (/\A\s*\>Alias\:\<\/a\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Alias parsing") if $tmp ne "\n";
            $tmp = <FHORIGIN>; die("unexpected Alias parsing") if $tmp ne "</th>\n";
            $tmp = <FHORIGIN>; die("unexpected Alias parsing") if not $tmp =~ /\A\s*\<td\>/;
            $tmp = <FHORIGIN>; die("unexpected Alias parsing") if not $tmp =~ s/\A\s*(.*?)\s*\Z/$1/;
            $alias = $tmp;
        } elsif (/\A\s*\>Assignee\:\<\/a\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Assignee parsing") if $tmp ne "\n";
            $tmp = <FHORIGIN>; die("unexpected Assignee parsing") if $tmp ne "</th>\n";
            $tmp = <FHORIGIN>; die("unexpected Assignee parsing") if not $tmp =~ s/\A\s*\<td\>\<span class\=\"vcard\"\>(.*)\Z/$1/;
            $assignee = $tmp;
        } elsif (/\A\s*\>QA Contact\:\<\/a\>\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected QA Contact parsing") if $tmp ne "\n";
            $tmp = <FHORIGIN>; die("unexpected QA Contact parsing") if $tmp ne "</th>\n";
            $tmp = <FHORIGIN>; die("unexpected QA Contact parsing") if not $tmp =~ s/\A\s*\<td\>\<span class\=\"vcard\"\>(.*)\Z/$1/;
            $qacontact = $tmp;
        } elsif (/\A\s*\<a href\=\"page\.cgi\?id\=fields.html\#importance\"\>\<u\>I\<\/u\>mportance\<\/a\>\<\/label\>\:\s*\Z/) {
            my $tmp;
            $tmp = <FHORIGIN>; die("unexpected Importance parsing") if $tmp ne "      </th>\n";
            $tmp = <FHORIGIN>; die("unexpected Importance parsing") if not $tmp =~ s/\A\s*\<td\>//;
            $importance = $tmp;
            while (<FHORIGIN>) {
                chomp;
                s/\A\s*//;
                s/\s*\Z//;
                last if $_ eq '</td>';
                $importance .= " $_";
            }
        } elsif (s/\A\s*id\=\"field_container_see_also\"\s*\>//) {
            $seealso = $_;
            while (<FHORIGIN>) {
                chomp;
                last if /\A\s*\<\/td\>\Z/;
                $seealso .= "$_\n";
            }
        } elsif (/\A\s*\<tr id\=\"(a\d+)\"/) {
            if ($1 ne 'a0') { # a0 is the table header, covered elsewhere.
                $attachments .= "$_\n";
                while (<FHORIGIN>) {
                    $attachments .= $_;
                    chomp;
                    $attachments .= "</tr>\n\n", last if /\A\s*\<\/td\>/;  # this chops out the "details" column.
                }
            }
        }
    }
    close(FHORIGIN);

    next if $skip_this_bug;

    die("No bugtitle found in bug $i") if not defined $bugtitle;
    die("No bugcomments found in bug $i") if not defined $bugcomments;
    die("No bugstatus found in bug $i") if not defined $bugstatus;
    die("No lastmod found in bug $i") if not defined $lastmod;
    die("No reportedtime found in bug $i") if not defined $reportedtime;
    die("No reportedby found in bug $i") if not defined $reportedby;
    die("No cclist found in bug $i") if not defined $cclist;
    die("No product found in bug $i") if not defined $product;
    die("No component found in bug $i") if not defined $component;
    die("No classification found in bug $i") if not defined $classification;
    die("No version found in bug $i") if not defined $version;
    die("No hardware found in bug $i") if not defined $hardware;
    die("No importance found in bug $i") if not defined $importance;
    die("No assignee found in bug $i") if not defined $assignee;
    die("No qacontact found in bug $i") if not defined $qacontact;
    die("No alias found in bug $i") if not defined $alias;
    die("No url found in bug $i") if not defined $url;
    die("No blocks found in bug $i") if not defined $blocks;
    die("No dependson found in bug $i") if not defined $dependson;
    die("No seealso found in bug $i") if not defined $seealso;

    if ($attachments ne '') {
        $attachments = "<table id=\"attachment_table\"><tr id=\"a0\"><th class=\"left\">Attachments</th></tr>\n$attachments\n</table>\n";
    }

    open(FHOUT, '>', 'data-in-progress') or die("Failed to open 'data-in-progress': $!");
    open(FHTEMPLATEIN, '<', 'template.html') or die("Failed to open 'template.html': $!");
    while (<FHTEMPLATEIN>) {
        chomp;
        s/\@bugnum\@/$i/g;
        s/\@bugtitle\@/$bugtitle/g;
        s/\@lastmod\@/$lastmod/g;
        s/\@reportedtime\@/$reportedtime/g;
        s/\@reportedby\@/$reportedby/g;
        s/\@bugcomments\@/$bugcomments/g;
        s/\@bugstatus\@/$bugstatus/g;
        s/\@duplicates\@/$duplicates/g;
        s/\@cclist\@/$cclist/g;
        s/\@product\@/$product/g;
        s/\@classification\@/$classification/g;
        s/\@component\@/$component/g;
        s/\@version\@/$version/g;
        s/\@hardware\@/$hardware/g;
        s/\@importance\@/$importance/g;
        s/\@assignee\@/$assignee/g;
        s/\@qacontact\@/$qacontact/g;
        s/\@attachments\@/$attachments/g;
        s/\@alias\@/$alias/g;
        s/\@url\@/$url/g;
        s/\@blocks\@/$blocks/g;
        s/\@dependson\@/$dependson/g;
        s/\@seealso\@/$seealso/g;
        s/\@sitename\@/$sitename/g;

        print FHOUT "$_\n";
    }
    close(FHTEMPLATEIN);
    close(FHOUT);

    system("mv 'data-in-progress' '$dir/$i'");
}

print("Static HTML pages are all generated!\n\n");

print("\n\n\nAll done!\n\n\n");

