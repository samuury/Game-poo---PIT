# Breakout Matemático

Projeto acadêmico de programação orientada a objetos inspirado em Breakout,
com perguntas de matemática e conhecimentos gerais. Há duas implementações:
Godot, a versão principal, e uma versão alternativa em Pygame.

## Godot

Requer Godot 4.4 ou superior. A cena principal é `Main.tscn`; o jogo cria a
cena, a interface e os elementos 3D por código.

Para abrir, importe `project.godot` no Godot e pressione **F5**, ou execute na
pasta do projeto:

```sh
godot --path .
```

O jogo tem modos Padrão e Random, três dificuldades, blocos especiais, boosts,
questionários e estatísticas por matéria. As matérias do quiz são escolhidas
antes da partida.

A janela abre em 1920x1080. **F11** alterna entre janela e tela cheia. O jogo
pausa automaticamente quando a janela perde o foco.

### Jogo e controles

- Modos Padrão e Random, três dificuldades e fases com formações predefinidas
  ou aleatórias.
- Blocos coloridos exigem de 1 a 4 batidas. Blocos cinza reforçados exigem o
  dobro das batidas de um bloco normal no modo Difícil; rachaduras indicam o
  dano. Blocos cinza e bombas também aparecem no modo Random.
- Bombas explodem em cadeia e danificam os blocos próximos.
- Cápsulas ativam questionários e podem conceder boosts. Perguntas erradas
  podem voltar como revisão, e a dificuldade se adapta por matéria.
- O banco inclui 337 perguntas gerais em Geografia, Ciências, História,
  Cultura, Tecnologia e Português, além de 12 tipos de matemática gerados na
  hora, incluindo Geometria e Múltiplos e Divisores.
- Analógico esquerdo move a raquete; **A** lança ou atira; **A/B/X/Y** respondem
  ao quiz; **Start** pausa. Teclado e mouse também podem ser usados.

O banco de conhecimentos gerais fica em `data/perguntas.json`.

### Gráficos

O menu **GRÁFICOS** permite configurar:

- Qualidade **BAIXA**, **MÉDIA**, **ALTA** (padrão) ou **ULTRA**. Ultra ativa
  MSAA, SSAO, sombras de até 8K e reflexos SSR no chão.
- Resolução da janela entre 1280x720 e 3840x2160; tela cheia usa a resolução do
  monitor.
- Escala 3D de 50% a 200%. Valores acima de 100% aplicam supersampling.
- Vinheta leve como efeito de tela.

As configurações são salvas em `user://config_breakout.cfg`. Em computadores
com menos desempenho, use qualidade Média ou Baixa, ou escala 3D de 75%.

### Trilha sonora

A trilha é original e sintetizada por código. Há música de menu, três faixas de
jogo com quatro camadas dinâmicas, música de tensão durante o quiz e vinhetas
de vitória e derrota. A bateria reage ao lançamento da bola e a melodia ao
progresso da partida. Os botões **MÚSICA** (quatro níveis) e **SOM** ficam no
menu.

Para recompor a trilha, são necessários Python 3, NumPy, SciPy e FFmpeg:

```sh
python3 tools/compor_trilha.py
```

### Persistência e exportação

O recorde é salvo em `user://recorde_breakout_matematico.txt`. Para incluir as
perguntas numa exportação, adicione `*.json` aos filtros de recursos não recurso
nas configurações de exportação do Godot.

### Testes

Com o executável do Godot disponível no `PATH`, importe os recursos uma vez e
rode os testes sem abrir janela:

```sh
godot --headless --import
godot --headless --path . --script res://tests/test_headless.gd
```

Os testes verificam o carregamento e a validade das perguntas, geração de
fases, limite de multibolas, progresso da partida, cápsulas, pontuação e
persistência do recorde.

### Arquivos principais

- `Main.tscn` e `Main.gd`: cena de entrada, fluxo do jogo, interface, física e
  boosts.
- `graphics.gd`: ambiente 3D e configurações gráficas.
- `music.gd`: trilha sonora dinâmica.
- `record_store.gd`: leitura e gravação do recorde.
- `quiz_bank.gd`: perguntas matemáticas, banco geral e fila de revisão.
- `level_gen.gd`: geração procedural das fases.
- `data/perguntas.json`: perguntas de conhecimentos gerais.
- `shaders/`: shaders do chão, blocos, paredes, raquete e pós-processamento.
- `music/`: arquivos da trilha sonora.
- `tools/compor_trilha.py`: compositor da trilha.
- `tests/test_headless.gd`: testes automatizados headless.

## Pygame

`TestGame.py` é uma implementação alternativa. Requer Python 3 e Pygame:

```sh
python -m pip install pygame
python TestGame.py
```

Essa versão salva o recorde em `recorde_breakout_matematico.txt` na pasta do
projeto.
