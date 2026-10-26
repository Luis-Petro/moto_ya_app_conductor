# Bitácora · Segundo Cerebro

Rastro de lo que se hace en este repo. Cada mañana la rutina del **Segundo Cerebro** (el Notion de
Luis) lee las líneas nuevas, las pasa a su Bitácora y le manda a Luis por push las preguntas
marcadas con ❓.

## Regla para cualquier agente (y para Luis)

1. Si tu sesión o ejecución **cambia algo** en el repo (código, contenido, config, docs), añade
   **una línea al final** de este archivo y súbela en el mismo commit o en el último push. Si solo
   leíste o investigaste, no escribas nada.
2. Una sola línea, con este formato:

   `- AAAA-MM-DD HH:MM · <agente> · <tipo> · <qué cambió y para qué, en una frase>[ · sigue: <próximo paso>][ · ❓ <pregunta para Luis>]`

   - Hora de Colombia (America/Bogota).
   - `agente`: el nombre de la rutina (`video-production`, `idea-research`…), `sesion-claude` u otro
     agente por su nombre, o `luis`.
   - `tipo`: `codigo` · `fix` · `contenido` · `publicacion` · `infra` · `docs` · `decision` · `metrica`.
   - `❓` solo para lo que únicamente Luis puede responder o decidir.
3. Solo se añade al final: nunca se edita ni se borra una línea anterior.
4. Nada de secretos, tokens, contraseñas ni datos de clientes o de terceros.

`.gitattributes` declara `BITACORA.md merge=union`: si dos agentes añaden su línea a la vez, git
conserva las dos en lugar de dar conflicto.

## Entradas

- 2026-10-26 12:30 · sesion-claude · docs · Se crea la bitácora del Segundo Cerebro y su regla en CLAUDE.md
