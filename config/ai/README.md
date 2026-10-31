# CielOS AI Toolkit

Toolkit completo per eseguire modelli AI locali su hardware modesto, specialmente GTX 1650 4GB.

## Strumenti Inclusi

### cielquant - Model Compression Pipeline
Compressione e quantization di modelli AI per hardware con risorse limitate.

```bash
# Analizza un modello
cielquant analyze deepseek-v4.1-flash

# Comprimi con Q2_K (2-bit) per GTX 1650
cielquant compress deepseek-v4.1-flash --bits 2 --level aggressive

# Distilla per creare modelli più piccoli
cielquant distill deepseek-v4.1-flash --student cielos-7b --ratio 0.25
```

### cielserve - Adaptive Inference Server
Server di inference con gestione automatica VRAM/CPU/offload.

```bash
# Avvia server con modello ottimizzato GTX 1650
cielserve --model deepseek-v4.1-flash-gtx1650

# Avvia in modalità CPU-only
cielserve --model deepseek-v4.1-flash --profile cpu-only
```

### cieldistill - Knowledge Distillation
Distillation di modelli grandi in versioni più piccole mantenendo qualità.

```bash
# Distilla DeepSeek V4.1 Flash in modello ottimizzato
cieldistill --teacher deepseek-v4.1-flash \
            --student cielos-deepseek-7b-optimal \
            --ratio 0.25 \
            --epochs 5
```

### cielai - AI System Status
Controlla lo stato del sistema AI e la configurazione hardware.

```bash
cielai status           # Stato AI e hardware
cielai diagnostics      # Diagnostica completa
cielai profile gtx-1650 # Profilo per GTX 1650
```

## DeepSeek V4.1 Flash - Ottimizzato per GTX 1650

### Configurazione Predefinita

```json
{
    "quantization": "Q2_K",
    "vram_target_mb": 3500,
    "cpu_offload": true,
    "context_length": 2048,
    "batch_size": 32,
    "cpu_threads": 10
}
```

### Performance Attesa

- **VRAM richiesto**: ~2GB (da 7GB FP16)
- **Velocità stimata**: ~5 tokens/secondo
- **Context window**: 2048 token
- **Riduzione dimensione**: 87% con Q2_K

## Installazione Automatica

```bash
# Installa DeepSeek V4.1 Flash con ottimizzazioni
./config/ai/installa-deepseek.sh
```

## Hardware Supportato

| GPU | Quantizzazione | VRAM Richiesto | Notes |
|-----|----------------|----------------|-------|
| GTX 1650 | Q2_K | ~2GB | Con CPU offload |
| RTX 30xx | Q3_K_M | ~3-4GB | Con Tensor cores |
| RTX 40xx | Q4_K_M | ~5-7GB | Full quality |

## File di Configurazione

- `/home/evixion/cielos/config/ai/deepseek-v4.1-flash.conf` - Configurazione principale
- `/home/evixion/cielos/config/ai/installa-deepseek.sh` - Script di installazione
- Ogni tool ha file di log in `~/.cache/cielos/ai/`