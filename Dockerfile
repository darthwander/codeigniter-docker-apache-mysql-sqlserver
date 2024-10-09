# Usar uma imagem base com PHP 8.0 e Apache
FROM php:8.0-apache

# Adicione esta linha após instalar o Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    unixodbc-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && docker-php-ext-install mysqli

# Instala pacotes necessários
RUN apt-get update && apt-get install -y \
    libzip-dev \
    && docker-php-ext-install zip

# Instale o driver do SQL Server compatível com PHP 8.0
RUN pecl install sqlsrv-5.10.1 pdo_sqlsrv-5.10.1 \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv

# Instalar Xdebug
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

# Habilitar o Xdebug
COPY ./xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Limpe o cache do apt
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# # Copiar os arquivos do projeto para o diretório padrão do Apache
COPY . /var/www/html/codeigniter

# Ajuste as permissões do diretório do projeto
RUN chown -R www-data:www-data /var/www/html/codeigniter && \
    chmod -R 775 /var/www/html/codeigniter

# Criar o diretório de logs
RUN mkdir -p /var/www/html/codeigniter/application/logs

# Copia o php.ini
RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini

# Adicione as configurações do Xdebug no php.ini
RUN echo "zend_extension=xdebug.so" >> /usr/local/etc/php/php.ini \
    && echo "xdebug.mode=debug" >> /usr/local/etc/php/php.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/php.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/php.ini \
    && echo "xdebug.client_port=9004" >> /usr/local/etc/php/php.ini \
    && echo "xdebug.log=/var/log/xdebug.log" >> /usr/local/etc/php/php.ini

RUN touch /var/setup_sqlserver.sh
RUN chmod +x /var/setup_sqlserver.sh

RUN echo "curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc" >> /var/setup_sqlserver.sh \
    && echo "curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list" >> /var/setup_sqlserver.sh \
    && echo "apt-get update" >> /var/setup_sqlserver.sh \
    && echo "ACCEPT_EULA=Y apt-get install -y msodbcsql18" >> /var/setup_sqlserver.sh \
    && echo "ACCEPT_EULA=Y apt-get install -y mssql-tools18" >> /var/setup_sqlserver.sh \
    && echo "echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc" >> /var/setup_sqlserver.sh \
    && echo "source ~/.bashrc" >> /var/setup_sqlserver.sh \
    && echo "apt-get install -y unixodbc-dev" >> /var/setup_sqlserver.sh

RUN /var/setup_sqlserver.sh

# Modifica o arquivo de configuração do Apache
RUN sed -i "s|DocumentRoot /var/www/html|DocumentRoot /var/www/html/codeigniter|" /etc/apache2/sites-available/000-default.conf && \
    echo "<Directory /var/www/html/codeigniter>\n    Options Indexes FollowSymLinks\n    AllowOverride All\n    Require all granted\n</Directory>" >> /etc/apache2/sites-available/000-default.conf

# Habilite o módulo do Apache
RUN a2enmod rewrite

# Expor a porta 8090 para o Apache
EXPOSE 80

# Alterar a porta padrão do Apache para 8090
RUN sed -i 's/80/8090/g' /etc/apache2/sites-available/000-default.conf

# Comando de inicialização
CMD ["apache2-foreground"]
