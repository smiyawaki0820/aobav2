#!/bin/bash

USAGE="bash $0 [DEST] [qsub]"

PYENV_NAME=$(pyenv version | awk -F ' ' '{print $1}')

__DIR__=$(cd $(dirname $0); pwd)
__FILE__=$(basename $0)

DIR_DATA=/groups2/gcb50246/miyawaki/SLUD2021/DialoGPT
FI_TRAIN_DB=$DIR_DATA/train_10K.128len.db
FI_TOKENIZER=$FI_TRAIN_DB/tokenizer
FI_VALID_TSV=$DIR_DATA/valid.tsv

DIR_MODEL=$1
DIR_LOG=$1/logs


if [ -z $DIR_MODEL ] && [ ! "$DIR_MODEL" = "qsub" ] ; then
    echo $USAGE
    exit 1
fi


if [ "$2" = "qsub" ] ; then
    echo "qsub"
    qsub -cwd -g gcb50246 \
        -N .${__FILE__} -j y \
        -l rt_G.small=1 -l h_rt=168:00:00 \
        ${__DIR__}/${__FILE__}

else
    source scripts/abci_setting.sh $PYENV_NAME
    
    echo "===== Train DialoGPT ====="
    mkdir -p $DIR_LOG $DIR_MODEL

    CUDA_VISIBLE_DEVICES=0 python LSP_train.py \
        --model_name_or_path rinna/japanese-gpt2-medium \
        --toker_name_or_path $FI_TOKENIZER \
        --init_checkpoint "None" \
        --train_input_file $FI_TRAIN_DB \
        --eval_input_file $FI_VALID_TSV \
        --output_dir $DIR_MODEL \
        --seed 42 \
        --max_seq_length 128 \
        --train_batch_size 128 \
        --gradient_accumulation_steps 8 \
        --eval_batch_size 64 \
        --learning_rate 1e-5 \
        --num_optim_steps 10 \
        --valid_step 5 \
        --warmup_steps 400 \
        --normalize_data true \
        --fp16 true \
        --lr_schedule noam \
        --loss_scale 0.0 \
        --no_token_id true \
        --pbar true \
        --ja \
    | tee ${DIR_LOG}/train_${DATE}.log

    echo "write ... ${DIR_MODEL}"
    echo "write ... ${DIR_LOG}/train_${DATE}.log"

fi
