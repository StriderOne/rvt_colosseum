#!/bin/bash

# Check if required arguments are provided
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 start_counter end_counter max_counter_inside gpu_batch_size"
    exit 1
fi

export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
sleep 1  # Give Xvfb a moment to start

## change data folder in train.py
## change tasks in RVT/rvt/utils/rvt_utils.py

# Directory setup
export eval_dir="/home/randuser/rvt_colosseum/eval"
export DEMO_PATH="/home/randuser/data"
export eval_episodes=25

# Create evaluation directory if it doesn't exist
mkdir -p "${eval_dir}"

# Initialize counters and device
counter=0
counter_inside=0
device=0  # Start with highest GPU number (0-7 for 8 GPUs)
NUM_GPUS=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | wc -l)
echo "$NUM_GPUS"
# Total number of available GPUs
# Check if dataset directory exists
# if [ ! -d "$DEMO_PATH" ]; then
#     echo "Error: Dataset directory $DEMO_PATH does not exist"
#     exit 1
# fi
# Main loop
task_list=close_box_2
# for task_list in ; do
    # if [[ $counter -ge $1 ]] && \
    #    [[ $counter -le $2 ]] && \
    #    [[ $counter_inside -le $3 ]] && \
    #    [[ $task_list == *_0 || $task_list == *_1  ]]  # Modify task pattern as needed
    # then
        # GPU device management - cycle through available GPUs

echo "$device:rvt:$task_list"

# Create log file
log_file="${eval_dir}/${task_list}_final.txt"
touch "$log_file" || {
    echo "Error: Cannot create log file $log_file"
    continue
}

# Run evaluation with specific GPU
CUDA_VISIBLE_DEVICES=$device python3 eval.py \
    --model-folder "/home/randuser/rvt_colosseum/runs" \
    --eval-datafolder "$DEMO_PATH" \
    --tasks "$task_list" \
    --eval-episodes "$eval_episodes" \
    --log-name "$eval_dir" \
    --device 0 \
    --headless \
    --model-name "model_14.pth" \
    --save-video &
# counter_inside=$((counter_inside + 1))
    # fi
    # counter=$((counter + 1))
# done
# Wait for all background processes to complete
wait
echo "Evaluation completed for $counter_inside tasks"




