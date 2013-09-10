<?php

if (empty($_FILES)) exit;

$file = $_FILES['file'];
$uppath = "uploads/";

$temp_file = $file['tmp_name'];
$target_file = str_replace('//','/',$uppath).$file['name'];

if (!is_dir($uppath)) {
    @umask(0);
    $ret = @mkdir($uppath, 0777);
    if ($ret === false) {
        echo "没有权限";
        exit;
    }
}

move_uploaded_file($temp_file, $target_file);

echo $target_file;
?>
