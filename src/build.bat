@echo off

set SRC=jquery.uploader.js
set MIN=../jquery.uploader.js

uglifyjs %SRC% -o %MIN% -c -m --comments "/\/*!/"