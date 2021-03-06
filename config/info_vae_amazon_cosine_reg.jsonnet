local SEED = 0;
local READER = "sentence_similarity";
local CUDA = 0;

local TASK_EMBEDDING_DIM = 100;
local GEN_EMBEDDING_DIM = 100;
local TASK_HIDDEN_DIM = 128;
local GEN_HIDDEN_DIM = 128;
local TASK_LATENT_DIM = 64;
local GEN_LATENT_DIM = 64;
local BATCH_SIZE = 48;
local NUM_LAYERS = 1;
local BIDIRECTIONAL = true;

local NUM_EPOCHS = 30;
local PATIENCE = 10;
local SUMMARY_INTERVAL = 10;
local GRAD_CLIPPING = 5;
local GRAD_NORM = 5;
local SHOULD_LOG_PARAMETER_STATISTICS = false;
local SHOULD_LOG_LEARNING_RATE = true;
local OPTIMIZER = "adam";
local LEARNING_RATE = 0.001;
local INIT_UNIFORM_RANGE_AROUND_ZERO = 0.1;

local TASK_KL_WEIGHT = {
  "type": "smoothed_sigmoid_annealed",
  "slope": 0.0025,
  "margin": 4750,
  "min_weight": 0.01,
  "max_weight": 0.5,
  "early_stop_iter": 4000
};
local GEN_KL_WEIGHT = {
  "type": "smoothed_sigmoid_annealed",
  "slope": 0.0025,
  "margin": 4750,
  "min_weight": 0.01,
  "max_weight": 0.5,
  "early_stop_iter": 4000
};


{
  "random_seed": SEED,
  "numpy_seed": SEED,
  "pytorch_seed": SEED,
  "dataset_reader": {
    "type": READER
  },
  "train_data_path": {
    "semantic": "data/processed/amazon/category_sim_train.tsv",
    "syntactic": "data/processed/amazon/sentiment_sim_train.tsv",
  },
  "validation_data_path": {
    "semantic": "data/processed/amazon/category_sim_val.tsv",
    "syntactic": "data/processed/amazon/sentiment_sim_val.tsv",
  },
  "vocabulary": {
    "max_vocab_size": 30000
  },
  "model": {
    "type": "info_vae",
    "task_encoder": {
      "type": "gaussian",
      "text_field_embedder": {
        "token_embedders": {
          "tokens": {
            "type": "embedding",
            "vocab_namespace": "tokens",
            "embedding_dim": TASK_EMBEDDING_DIM,
          }
        }
      },
      "encoder": {
        "type": "lstm",
        "input_size": TASK_EMBEDDING_DIM,
        "hidden_size": TASK_HIDDEN_DIM,
        'num_layers': NUM_LAYERS,
        "bidirectional": BIDIRECTIONAL,
      },
      "latent_dim": TASK_LATENT_DIM,
    },
    "gen_encoder": {
      "type": "gaussian",
      "text_field_embedder": {
        "token_embedders": {
          "tokens": {
            "type": "embedding",
            "vocab_namespace": "tokens",
            "embedding_dim": GEN_EMBEDDING_DIM,
          }
        }
      },
      "encoder": {
        "type": "lstm",
        "input_size": GEN_EMBEDDING_DIM,
        "hidden_size": GEN_HIDDEN_DIM,
        'num_layers': NUM_LAYERS,
        "bidirectional": BIDIRECTIONAL,
      },
      "latent_dim": GEN_LATENT_DIM,
    },
    "decoder": {
      "type": "variational_decoder",
      "target_embedder": {
        "token_embedders": {
          "tokens": {
            "type": "embedding",
            "vocab_namespace": "tokens",
            "embedding_dim": GEN_EMBEDDING_DIM,
          }
        }
      },
      "rnn": {
        "type": "lstm",
        "input_size": GEN_EMBEDDING_DIM + TASK_LATENT_DIM + GEN_LATENT_DIM,
        'num_layers': NUM_LAYERS,
        "hidden_size": GEN_HIDDEN_DIM,
      },
      "latent_dim": TASK_LATENT_DIM + GEN_LATENT_DIM
    },
    "task_kl_weight": TASK_KL_WEIGHT,
    "gen_kl_weight": GEN_KL_WEIGHT,
    "task_temperature": 1e-5,
    "gen_temperature": 1e-5,
    "initializer": [
      [".*", {"type": "uniform", "a": -INIT_UNIFORM_RANGE_AROUND_ZERO, "b": INIT_UNIFORM_RANGE_AROUND_ZERO}]
    ]
  },
  "iterator": {
    "type": "bucket",
    "batch_size" : BATCH_SIZE,
    "sorting_keys": [["sentence", "num_tokens"]],
    "biggest_batch_first": true,
  },
  "trainer": {
    "type": 'callback',
    "num_epochs": NUM_EPOCHS,
    "cuda_device": CUDA,
    "optimizer": {
      "type": OPTIMIZER,
      "lr": LEARNING_RATE
    },
    "callbacks": [
      {"type": "gradient_norm_and_clip", "grad_norm": GRAD_NORM, "grad_clipping": GRAD_CLIPPING},
      {
        "type": "checkpoint",
        "checkpointer": {"num_serialized_models_to_keep": -1}
      },
      {"type": "track_metrics", "patience": PATIENCE, "validation_metric": "+BLEU"},
      "validate",
      "generate_paraphrases",
      "generate_sample_reconstruction",
      "log_to_tensorboard"
    ]
  }
}
