FROM ruby:3.2

# Instalar dependências do sistema
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

# Definir o diretório de trabalho
WORKDIR /app

# Copiar arquivos necessários para o bundle install
COPY *.gemspec /app/
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
COPY lib /app/lib

# Instalar bundler compatível com Ruby 3.2
RUN gem install bundler --no-document

# Rodar bundle install
RUN bundle install

# Copiar o restante da aplicação
COPY . /app

# Expor a porta padrão do Rails
EXPOSE 3000

# Comando padrão para iniciar o servidor Rails
CMD ["rails", "server", "-b", "0.0.0.0"]

