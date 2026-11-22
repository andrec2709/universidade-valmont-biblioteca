## Informações Básicas

- Nome do projeto: Sistema de Empréstimo de Livros para Biblioteca

## Elevator Pitch

Este projeto consiste em gerenciar os empréstimos realizados pela biblioteca. O público alvo são principalmente os recepcionistas e bibliotecários. O principal objetivo é ter informações centralizadas e bem organizadas sobre empréstimos realizados, para melhorar a eficiência do atendimento.

## Escopo Incluso

O sistema registrará:

- Dados cadastrais de usuários
- Dados de livros no acervo.
- Histórico de empréstimos com status (exemplo: "devolvido", "em atraso", "pendente" (status a definir)).
- Cadastro de exemplares de cada livro no acervo, para controle unitário, utilizando código patrimonial.

## Escopo Excluso

O sistema não registrará informações financeiras relativas a pagamentos por dano aos exemplares, ou qualquer outro tipo de transação financeira realizada decorrente do empréstimo de livros.

## Perfis de uso

- Bibliotecário:
	- Registrar novos livros e exemplares, empréstimos, atualizar status de empréstimos. Terá controle sobre essas informações através de sistema externo, como um web app que interage com o sistema do banco de dados.
- Usuário:
	- O usuário final terá contato com o sistema através de sistema externo para realização de cadastro na biblioteca (e.g. página da web).

