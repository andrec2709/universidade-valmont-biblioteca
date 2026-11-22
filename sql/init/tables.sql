BEGIN;

CREATE SCHEMA IF NOT EXISTS biblioteca AUTHORIZATION uni_valmont_admin;

-- Cria o type de condições usado na tabela de cópias, caso não exista
DO $$
BEGIN
	CREATE TYPE biblioteca.copia_condicoes AS ENUM ('regular', 'manutencao', 'danificado', 'perdido');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS biblioteca.usuarios (
	user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	cpf VARCHAR(11) NOT NULL UNIQUE,
	nome VARCHAR(255) NOT NULL,
	senha VARCHAR(255) NOT NULL,
	data_nascimento DATE NOT NULL,
	email VARCHAR(255) NOT NULL,
	ativo BOOLEAN NOT NULL DEFAULT FALSE,
	data_cadastro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT check_cpf_format CHECK (cpf ~ '^[0-9]{11}$'),
	CONSTRAINT check_email_format CHECK (email ~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$')
);

-- Define o atributo email de biblioteca.usuarios como único na expressão LOWER(email)
-- (garante que e-mail são insensíveis a letras maiúsculas e minúsculas)
CREATE UNIQUE INDEX usuarios_lower_email ON biblioteca.usuarios(LOWER(email));

CREATE TABLE IF NOT EXISTS biblioteca.autores (
	autor_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	nome VARCHAR(255) NOT NULL UNIQUE,
	CONSTRAINT check_nome_len CHECK (LENGTH(nome) > 0)
);

CREATE TABLE IF NOT EXISTS biblioteca.obras (
	obra_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	titulo_original VARCHAR(255) NOT NULL,
	criador_principal_id BIGINT,
	CONSTRAINT obras_criador_principal_id_fkey FOREIGN KEY (criador_principal_id) REFERENCES biblioteca.autores(autor_id) ON DELETE SET NULL,
	CONSTRAINT check_titulo_original_len CHECK (LENGTH(titulo_original) > 0),
	CONSTRAINT unique_obras_titulo_original_criador_principal_id UNIQUE (titulo_original, criador_principal_id)
);

CREATE TABLE IF NOT EXISTS biblioteca.editoras (
	editora_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	nome VARCHAR(255) NOT NULL UNIQUE,
	CONSTRAINT check_nome_len CHECK (LENGTH(nome) > 0)
);

CREATE TABLE IF NOT EXISTS biblioteca.edicoes (
	edicao_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	obra_id BIGINT NOT NULL,
	editora_id BIGINT,
	titulo VARCHAR(255) NOT NULL,
	descricao TEXT,
	isbn VARCHAR(13),
	data_publicacao DATE,
	label_edicao VARCHAR(100),
	CONSTRAINT edicoes_obra_id_fkey FOREIGN KEY (obra_id) REFERENCES biblioteca.obras(obra_id) ON DELETE CASCADE,
	CONSTRAINT edicoes_editora_id_fkey FOREIGN KEY (editora_id) REFERENCES biblioteca.editoras(editora_id) ON DELETE SET NULL,
	CONSTRAINT check_titulo_len CHECK (LENGTH(titulo) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_isbn_unique ON biblioteca.edicoes(isbn) WHERE isbn IS NOT NULL;

CREATE TABLE IF NOT EXISTS biblioteca.edicoes_autores (
	edicao_autor_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	autor_id BIGINT NOT NULL,
	edicao_id BIGINT NOT NULL,
	papel VARCHAR(50) NOT NULL,
	CONSTRAINT edicoes_autores_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES biblioteca.autores(autor_id) ON DELETE CASCADE,
	CONSTRAINT edicoes_autores_edicao_id_fkey FOREIGN KEY (edicao_id) REFERENCES biblioteca.edicoes(edicao_id) ON DELETE CASCADE,
	CONSTRAINT unique_autor_id_edicao_id_papel UNIQUE(autor_id, edicao_id, papel)
);

CREATE TABLE IF NOT EXISTS biblioteca.copias (
	copia_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	edicao_id BIGINT,
	cod_patrimonial VARCHAR(100) NOT NULL UNIQUE,
	condicao biblioteca.copia_condicoes NOT NULL DEFAULT 'regular',
	CONSTRAINT copias_edicao_id_fkey FOREIGN KEY (edicao_id) REFERENCES biblioteca.edicoes(edicao_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS biblioteca.emprestimos (
	emprestimo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	user_id BIGINT NOT NULL,
	copia_id BIGINT NOT NULL,
	data_emprestimo DATE NOT NULL DEFAULT CURRENT_DATE,
	data_prevista_devolucao DATE NOT NULL,
	data_devolucao DATE,
	observacao TEXT,
	CONSTRAINT emprestimos_user_id_fkey FOREIGN KEY (user_id) REFERENCES biblioteca.usuarios(user_id) ON DELETE CASCADE,
	CONSTRAINT emprestimos_copia_id_fkey FOREIGN KEY (copia_id) REFERENCES biblioteca.copias(copia_id) ON DELETE CASCADE,
	CONSTRAINT check_data_devolucao CHECK(data_devolucao IS NULL OR data_devolucao >= data_emprestimo)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unico_emprestimo_ativo_por_copia 
ON biblioteca.emprestimos(copia_id)
WHERE data_devolucao IS NULL;

-- Não permite excluir o empréstimo se ele não foi finalizado
CREATE OR REPLACE FUNCTION fn_bloquear_exclusao_emprestimo_nao_devolvido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	IF OLD.data_devolucao IS NULL THEN
		RAISE EXCEPTION 'Não é possível deletar o empréstimo %: ainda não foi finalizado.', OLD.emprestimo_id
			USING ERRCODE = 'EDF01';
	END IF;

	RETURN OLD;
END;
$$;

-- Trigger que executa a função de bloquear remoção de empréstimo se o mesmo está em progresso
CREATE TRIGGER trg_bloquear_exclusao_emprestimo_nao_devolvido
BEFORE DELETE ON biblioteca.emprestimos
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_exclusao_emprestimo_nao_devolvido();

-- Bloqueia empréstimos para usuários não ativos
CREATE OR REPLACE FUNCTION fn_bloquear_emprestimo_usuario_nao_ativo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	PERFORM 1 from biblioteca.usuarios
	WHERE user_id = NEW.user_id
	AND ativo;

	IF NOT FOUND THEN
	 RAISE EXCEPTION 'Não é possível realizar o empréstimo: usuário % não está ativo.', NEW.user_id
	 	USING ERRCODE = 'UNAOA';
	END IF;

	RETURN NEW;
END;
$$;

CREATE TRIGGER bloquear_emprestimo_usuario_nao_ativo
BEFORE INSERT ON biblioteca.emprestimos
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_emprestimo_usuario_nao_ativo();

-- Função que detecta empréstimos pendentes antes de excluir usuário
CREATE OR REPLACE FUNCTION fn_bloquear_exclusao_com_pendencia_usuarios()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	IF EXISTS (
		SELECT 1
		FROM biblioteca.emprestimos
		WHERE user_id = OLD.user_id
		AND data_devolucao IS NULL
	) THEN
		RAISE EXCEPTION 'Não é possível deletar o usuário %: existem empréstimos pendentes.', OLD.user_id
			USING ERRCODE = 'UDF01';
	END IF;

	RETURN OLD;
END;
$$;

-- Trigger que roda antes de deletar usuários, verificando pendências de empréstimos
-- Se tiver pendências, o delete falha com ERRCODE = UDF01
CREATE TRIGGER trg_bloquear_exclusao_com_pendencia_usuarios
BEFORE DELETE ON biblioteca.usuarios
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_exclusao_com_pendencia_usuarios();

-- Detecta cópias em empréstimo ativo
CREATE OR REPLACE FUNCTION fn_bloquear_exclusao_com_pendencia_copias()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	IF EXISTS (
		SELECT 1
		FROM biblioteca.emprestimos
		WHERE copia_id = OLD.copia_id
		AND data_devolucao IS NULL
	) THEN
		RAISE EXCEPTION 'Não é possível deletar a cópia %: existem empréstimos pendentes.', OLD.copia_id
			USING ERRCODE = 'CDF01';
	END IF;

	RETURN OLD;
END;
$$;

-- Trigger que evita remoção de cópia se está em empréstimo ativo
CREATE TRIGGER trg_bloquear_exclusao_com_pendencia_copias
BEFORE DELETE ON biblioteca.copias
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_exclusao_com_pendencia_copias();

COMMIT;