#!/bin/bash
# Created by Philip R. Simonson
# Download required packages for updating steam client.

urls=('https://cdn.steamstatic.com/client/bins_ubuntu12.zip.vz.6a4ad992542188fa94c83da33e3f90829ba5ff4e_29141792' 'https://cdn.steamstatic.com/client/bins_sdk_ubuntu12.zip.vz.6ae839ae13bb1bb9d79b324b5dfe419facb54985_19548529' 'https://cdn.steamstatic.com/client/bins_codecs_ubuntu12.zip.vz.6592f3734983aaf25efdad3db98c8428a0dd6c1a_8752219' 'https://cdn.steamstatic.com/client/bins_misc_ubuntu12.zip.vz.4ec7cfd5b7753c8a06ba7a8338390d46c499de90_18659517' 'https://cdn.steamstatic.com/client/webkit_ubuntu12.zip.vz.dd14e17f61608201a3bfb69b33216ab2c1acafab_79885839' 'https://cdn.steamstatic.com/client/bins_misc_ubuntu12.zip.vz.4ec7cfd5b7753c8a06ba7a8338390d46c499de90_18659517' 'https://cdn.steamstatic.com/client/webkit_ubuntu12.zip.vz.dd14e17f61608201a3bfb69b33216ab2c1acafab_79885839' 'https://cdn.steamstatic.com/client/runtime_scout_ubuntu12.zip.06b1391e81cd5a855cfe38064fec799e76c7a678' 'https://cdn.steamstatic.com/client/runtime_sniper_ubuntu12.zip.cd8665cc23cd5ef8e5cbb1e2a5915d83529cdf30')

for url in ${urls[@]}; do wget -c "$url"; done

