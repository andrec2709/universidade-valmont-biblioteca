## Entidade: Usuario
### Descrição

Representa a pessoa física que realizará empréstimos de livros.

### Sinônimos

Cliente, consumidor, mutuário, tomador

### Atributos

- user_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- cpf: VARCHAR(11), UNIQUE, NOT NULL, `CHECK (cpf ~ '^[0-9]{11}$')`;
- nome: VARCHAR(255), NOT NULL;
- senha: VARCHAR(255), NOT NULL; Obs: senha será armazenada sob forma de hash.
- data_nascimento: DATE, NOT NULL;
- email: VARCHAR(255), UNIQUE, NOT NULL; Obs: não diferencia letras maiúsculas de minúsculas para considerar singularidade.
- ativo: BOOLEAN, NOT NULL, DEFAULT FALSE;
- data_cadastro: TIMESTAMPTZ, NOT NULL, DEFAULT CURRENT_TIMESTAMP;

## Entidade: Autor

### Descrição

Representa um autor.

### Sinônimos

Não há sinônimos no momento.

### Atributos

- autor_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- nome: VARCHAR(255), NOT NULL, UNIQUE;

## Entidade: EdicoesAutores

### Descrição

Representa autores de uma edição de uma obra específica.

### Sinônimos

Escritor, tradutor, ilustrador.

### Atributos

- edicao_autor_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- autor_id: BIGINT, FK Autor(autor_id), NOT NULL;
- edicao_id: BIGINT, FK Edicao(edicao_id), NOT NULL;
- papel: VARCHAR(50), NOT NULL;

### Constraints

- UNIQUE (autor_id, edicao_id, papel);

## Entidade: Obra

### Descrição

Representa um trabalho literário dentro do banco de dados.

### Sinônimos

Trabalho

### Atributos

- obra_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- titulo_original: VARCHAR(255), NOT NULL;
- criador_principal_id: BIGINT, FK Autor(autor_id);

### Constraints

UNIQUE (titulo_original, criador_principal_id);

## Entidade: Editora

### Descrição

Representa uma editora.

### Sinônimos

Não há sinônimos no momento.

### Atributos

- editora_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- nome: VARCHAR(255), NOT NULL, UNIQUE;
## Entidade: Edicao

### Descrição

Representa uma específica edição de uma obra.

### Sinônimos

Versão

### Atributos

- edicao_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- obra_id: BIGINT FK Obra(obra_id), NOT NULL;
- editora_id: BIGINT, FK Editora(editora_id);
- titulo: VARCHAR(255), NOT NULL;
- descricao: TEXT;
- isbn: VARCHAR(13);
- data_publicacao: DATE;
- label_edicao: VARCHAR(100);

### Indices

- CREATE UNIQUE INDEX idx_isbn_unique ON edicao (isbn) WHERE isbn IS NOT NULL;

## Entidade: Copia

### Descricão

Representa uma cópia de uma edição de uma obra específica.

### Sinônimos

Não há sinônimos no momento.

### Atributos

- copia_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- edicao_id: BIGINT FK Edicao(edicao_id), NOT NULL;
- cod_patrimonial: VARCHAR(100), NOT NULL, UNIQUE;
- condicao: ENUM('regular', 'manutencao', 'danificado', 'perdido'), NOT NULL, DEFAULT 'regular';

## Entidade: Emprestimo

### Descrição

Representa um empréstimo de uma cópia.

### Sinônimos

Não há sinônimos no momento.

### Atributos

- emprestimo_id: BIGINT, GENERATED ALWAYS AS IDENTITY, PRIMARY KEY;
- user_id: BIGINT, FK Usuario(user_id), NOT NULL;
- copia_id: BIGINT, FK Copia(copia_id), NOT NULL;
- data_emprestimo: DATE, NOT NULL, DEFAULT CURRENT_DATE;
- data_prevista_devolucao: DATE, NOT NULL;
- data_devolucao: DATE;
- observacao: TEXT;

### Constraints

- CHECK (data_devolucao is NULL OR data_devolucao >= data_emprestimo);

### Indices

- CREATE UNIQUE INDEX idx_unico_emprestimo_ativo_por_copia ON emprestimo(copia_id) WHERE data_devolucao IS NULL; Postgres especifico.

### Considerações

- Atributo "observacao": serve para descrever detalhes diversos do empréstimo. Por exemplo, pode especificar o estado do livro no momento do empréstimo (e.g. "Livro está com dano na capa, miolo do livro solto");