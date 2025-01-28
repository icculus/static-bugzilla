<?php

function notfound() {
    header('HTTP/1.0 404 Not Found');
    header('Content-Type: text/plain; charset=utf-8');
    print("\n\nNo such bug ID.\n\n\n");
    exit(0);
}

if (!isset($_REQUEST['id'])) {
    notfound();
}

$id = (int) $_REQUEST['id'];
$thousandsdir = (int) ($id / 1000);
$hundredsdir = (int) (($id % 1000) / 100);
$path = "bugs-html/$thousandsdir/$hundredsdir/$id";

if (!file_exists($path)) {
    notfound();
} else if (file_exists("$path-SPAM")) {
    notfound();
} else if (@readfile($path) === false) {
    notfound();
}

exit(0);

?>
