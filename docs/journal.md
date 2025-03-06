## 05/03/2025

1) Created fork of repo: https://github.com/StriderOne/rvt_colosseum
2) Created scripts for using docker
3) Inside docker now pull my repo, install dependencies and then set up volume between my local files and container's ones
4) Previous point made troubles with model which loaded in same folder as volume, so the volume erase all futher changes (according to dockerfile) in folder, that's why now store models in another folder: home/randuser/rvt/runs 
5) Use ./collect_dataset.sh from robot-colosseum to create dataset with variations. Using datasets from https://huggingface.co/datasets/colosseum/colosseum-challenge/tree/main doesn't work, probably because pickles files were created with higher numpy version/ For example, I was able to open that pickles on python=3.11 with numpy=1.26, but got error in docker on python 3.8 and numpy=1.24.1

## 06/03/2025

1) Refactor all dockerfile: use venv instead of system python, clone rep from my github, volume only for rvt folder, change folder of models (volume erase it otherwise)
2) Added patches with changes for file, which are not from this rep
3) When container has started: 

```
. venv/bin/activate
./robot-colosseum/collect_dataset.sh
cd ~/rvt_colosseum/rvt
bash run_eval_variations.sh 0 50 5 3
```