$modelname "C:\Work\HL\sc_towerdefense2\cratemodel\crate.mdl"
$cd "\Work\HL\sc_towerdefense2\cratemodel\"
$cdtexture "\Work\HL\sc_towerdefense2\cratemodel\"
$cliptotextures

$scale 1.0

// bodygroups: use relative path from $cd
$bodygroup body
{
studio "./0_weak"
studio "./1_normal"
studio "./2_strong"
studio "./3a_strongest"
studio "./3b_explosive"
}

// sequences: all sequences are in $cd
$sequence idle1 "idle1" loop fps 30 ACT_IDLE 1
