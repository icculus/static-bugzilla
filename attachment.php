<?php

function notfound() {
    header('HTTP/1.0 404 Not Found');
    header('Content-Type: text/plain; charset=utf-8');
    print("\n\nNo such attachment ID.\n\n\n");
    exit(0);
}

if (!isset($_REQUEST['id'])) {
    notfound();
}

$id = (int) $_REQUEST['id'];
$thousandsdir = (int) ($id / 1000);
$hundredsdir = (int) (($id % 1000) / 100);
$path = "attachments/$thousandsdir/$hundredsdir/$id";

if (!file_exists("$path/data")) {
    notfound();
}

$content_disposition = false;
if (file_exists("$path/content-disposition")) {
    $content_disposition = file_get_contents("$path/content-disposition");
}

$content_type = false;
if (file_exists("$path/content-type")) {
    $content_type = file_get_contents("$path/content-type");
}

if ($content_disposition !== false) {
    header("Content-disposition: $content_disposition");
}

if ($content_type !== false) {
    header("Content-Type: $content_type");
}

$flen = filesize("$path/data");
if ($flen !== false) {
    header("Content-Length: $flen");
}

if (@readfile("$path/data") === false) {
    notfound();
}

exit(0);

?>

