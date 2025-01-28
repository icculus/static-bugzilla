# static-bugzilla

## What is this?

This is a hacky little piece of code I wrote to convert my ancient and
abandoned Bugzilla installation into a static, read-only archive.

This let me decommission the Bugzilla instance but leave the data publically
available, keeping the most important URLs continuing to function. As an added
benefit, the data serves faster and the server no longer needs to keep
Bugzilla, MySQL, jobqueue.pl, etc, running.

It might work for you.

It pulls all the data it needs from the public website, so you can do it
without direct access to the database. This means you could probably use it
to archive someone else's Bugzilla install that you don't control, given time
and bandwidth to pull everything.

It is intended to make the individual bug pages and attachments available on
their original URLs; everything else goes to a 404 page.

## How to use this.

- Clone this repository somewhere. Make sure perl and the curl command line
  tool are installed. I ran this on Linux, it probably works on macOS, Windows
  will probably need some small effort to set up.
- If you intend to replace Bugzilla instead of just keep a static archive for
  yourself, then on the Bugzilla webserver, you will need a way to run PHP
  scripts. You will no longer need Perl, MySQL, or cgi-bin support.
- Edit the top of `make_bugzilla_static_readonly.pl`. Look for the block
  that says `# EDIT THESE LINES TO FIT YOUR BUGZILLA INSTALL!` ... read each
  line and change it to match your target installation.
- Run `make_bugzilla_static_readonly.pl` from the directory it is installed in.
  It will create directories in the same place as it works. Make sure you can
  access the Bugzilla installation over the network from this computer.
- The script will begin pulling in data it needs from Bugzilla. If the script
  is interrupted, it will pick up where it left off next time. It doesn't
  move files into place until they are ready, so a power outage shouldn't
  leave data half-prepared.
- Downloading may take significant time. Running this script _directly on the
  webserver itself_ (so no bandwidth delays) still took about four hours to
  download 6678 bugs and 3639 attachments, as each HTTP request to Bugzilla
  can take a few seconds. I shudder at running this against mozilla.org's
  bugtracker which is dangerously close to 2 million bugs at the time of this
  writing.
- After download, the script will start generating static HTML pages for each
  bug. This is pretty fast; my laptop chewed through 6678 bugs in 38 seconds,
  but like the downloads, it is able to pick up where it left off if
  interrupted.

If you're replacing Bugzilla:

- Edit index.html and replace `noreply@example.com` with your email address (or
  change the text in some other way).
- After the script runs successfully, shut down Bugzilla on your server and
  move the install out of the way. Copy this directory in its place, so that
  show_bug.php will serve from the Bugzilla instance's root URL. The attachments
  and bugs-html directories that the script generated should be here, too.
- Change your webserver install so that show_bug.cgi requests go to
  show_bug.php and attachment.cgi requests go to attachment.php...and that
  all of these requests run as PHP pages. Note that many Bugzilla installations
  have a second domain for attachments (for some security reason I never
  understood), so attachment.cgi might run from, say, bugzilla.example.com and
  also bugzilla-attachments.example.com, depending on your site's config.)
- Make sure the webserver serves index.html for all 404 responses, which
  explains that Bugzilla is gone and most of its URLs are no longer available.
  Feel free to edit this index.html as appropriate.
- Make sure the webserver serves images/favicon.ico and has the correct mimetype.
- There is an Apache2 .htaccess file to block off files that shouldn't be
  accessed directly on the web; you might have to deal with yourself this if
  not using Apache.


Once you're happy with everything:

- You can delete `original-bugs-html`...but it is safe to leave it. Please
  note that you won't be able to generate this data again unless you put the
  original Bugzilla install back in place, so it might be better to leave it
  here, in case you want to tweak the template or fix a script bug and rebuild
  the static pages, etc.


## I have bugs that are just spam that bots posted.

Delete the static HTML files for them and the PHP code will report it as an
invalid bug. Since re-running the script will regenerate the static HTML, you
can also put a zero-byte file named BUGNUMBER-SPAM in the directory next to the
static HTML (so bug number 6312 would have a file located at
`bugs-html/6/3/6312-SPAM`). If this file exists, the PHP code will treat the
bug report number as if it's invalid.


## My bugzilla looked different.

You probably have to hand-edit template.html to match your site. This might
take some effort. Pay attention for `@symbol@` things in that file; those are
replaced with bug-specific data when the static pages are generated.


## What if this doesn't work?

This worked for my Bugzilla install, but the code is fragile in many ways, so
a different version of Bugzilla, or some theme, or even just a quirk of a bug
report that I didn't run into, etc, might break it.

If you have problems, [file a bug](https://github.com/icculus/static-bugzilla/issues),
or better yet, [send a patch](https://github.com/icculus/static-bugzilla/pulls), and
we can talk it through.

## Thanks!

--ryan.

