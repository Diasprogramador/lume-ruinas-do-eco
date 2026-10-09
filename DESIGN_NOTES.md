# Lume: Ruínas do Eco

## Instalação móvel — outubro de 2026

Preservar a direção existente: fundo #111922, texto #e7eedf, acento verde #a9d8c5 no PC e âmbar #e8bd80 no toque. Georgia para títulos e instruções. Opções Android / iPhone ficam ao lado do download Windows; diálogo nativo acessível, com duas etapas: baixar offline e adicionar à tela inicial. Estados explícitos de progresso, sucesso, erro e atualização pendente. Ícone com máscara de Lume e relicário âmbar dentro da área segura para recortes do sistema.

Protótipo original de exploração e combate lateral no Godot 4.
Direção: ruínas subterrâneas com arcos antigos, pequenas luzes vivas e silhuetas em camadas.
Paleta: abismo #071222, pedra #182b3e, névoa #456277, lume #8eeed2, marfim #e8efe5, perigo #ed887c.
Interface: títulos grandes, informações pequenas e legíveis; saúde em sementes luminosas.
Assinatura: protagonista de máscara oval e capa verde, cercado de vagalumes.
Scripts separados por responsabilidade: jogador, inimigo e composição da fase.

## Segunda versão

Após o feedback de que o protótipo estava ruim: fundo ilustrado original integrado em paralaxe, terreno rochoso irregular com vegetação e cogumelos, personagem em SVG com máscara assimétrica, capa em camadas e lâmina. Evitar retornar aos arcos geométricos repetidos da primeira versão.
Jogabilidade: pulo duplo, direção vertical de ataques, rebote ao atacar para baixo, dash mais frequente, câmera que antecipa a direção, recuo preservado ao sofrer dano, preparação legível do chefe, partículas e sons sintetizados. Quinze verificações de integração em `tests/gameplay.gd`.

## Terceira versão

Interface com máscaras de vida e reservatório circular de energia, pequenos indicadores de cargas de magia, custo e estado das habilidades, contador separado de sementes, barra ornamental do chefe e menus clicáveis com fonte serifada. Ajuda explica todas as habilidades e pausa a ação. Interface escala com a janela, seguindo a resolução base de 1280 × 720.
Combate: combo 1/1/2, ataque carregado, energia obtida por golpes, concentração para curar, projétil penetrante, explosão ascendente e mergulho em área. Efeitos especiais desenhados em camadas com arcos, runas, pilares e estilhaços; espada animada conforme a direção e fase do golpe. Escalada com deslize e salto na parede. Suíte ampliada para 28 verificações.

## Quarta versão

Menu com título à esquerda e opções à direita. Configurações seguem convenções: treze controles em duas colunas, captura com modal, conflitos explicitados, restauração de padrões, volumes separados e opções de vídeo. Dicas atualizadas dinamicamente após remapear. Loja com quatro prévias de capas e saldo persistente; três cores compráveis sem alterar a máscara ou a arma do personagem.
Áudio original offline: pads, baixo e sinos para exploração; arpejos e percussão para o chefe. Loops estéreo com transição suave, canais independentes e quinze efeitos WAV. Preferências e progressão cosmética em ConfigFile; 31 verificações adicionais de interface, persistência, compra e áudio.

## Quinta versão — cinco regiões

A fase inicial dobrou de 4.300 para 8.600 unidades. Outras quatro regiões chegam a 11.000 unidades, com ilhas, minas, aquedutos e fornalhas; 78 sementes no total. Paletas: jardins #8eeed2, brejo #dfb0ed, minas #bca5ff, inverno #a5eaff e cinzas #ffb16e. Fundos ilustrados originais mantêm a direção da arte existente, com paralaxe e detalhes animados. Cenários procedurais são fallback caso a ilustração não esteja importada.

Portais à direita abrem após o guardião; à esquerda é possível voltar. Sementes antigas mantêm seus identificadores para preservar o progresso cosmético. Layout, paleta e encontros ficam em levels.gd. O HUD mantém Georgia, máscaras de vida e painéis discretos. Barra do percurso e anúncio breve da região situam o jogador.

Combate: lâminas de luz afiladas com varredura direcional, partículas rápidas, rastros de magia, espirais ascendentes e onda de choque elíptica. 53 verificações de campanha cobrem transições, retorno, guardiões, coleta, santuários e conectividade conservadora de plataformas, além das suítes anteriores.

## Sexta versão — criaturas e interface ornamental

Dez silhuetas vetoriais originais em assets/characters: besouro de musgo / guardião de raízes; fungo ambulante / vigia dos esporos; artrópode cristalino / sentinela facetada; mariposa / cavaleiro alado da geada; caranguejo de brasa / armadura de fornalha. Silhuetas e materiais mudam por região, não apenas a cor. Animação de respiração, oscilação de asas representada pela escala, esporos e brasas em movimento. Colisões e dano preservam as dimensões de combate anteriores.

Interface inspirada na delicadeza sombria de metroidvanias, com identidade Lume: folhas de luz para a vida, relicário oval de energia, marfim #edf0df, tinta #111a25 e filigranas #abb8b3. Menu central serifado, opções sem caixas pesadas, foco de teclado visível, HUD oculto no menu. Cinco ícones pequenos substituem cartões grandes de habilidades; instruções detalhadas continuam na ajuda H. Cabeçalho e barra do guardião recebem ornamentos. Preferências, loja e remapeamento permanecem acessíveis.
