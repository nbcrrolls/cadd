#!/bin/bash

ls */*.log|xargs -ti sh -c 'head -29 {} | tail -1 ' >> temp_energies
ls -d */ > temp_dirs
paste temp_dirs temp_energies > temp_pasted
sort -k 3 -g temp_pasted | head -n 500 > screen_result_summary.log

rm temp_dirs
rm temp_pasted
rm temp_energies


