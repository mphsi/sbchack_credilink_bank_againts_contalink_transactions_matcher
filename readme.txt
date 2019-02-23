Proyecto para generar el paquete .zip para hacer deploy a una función de lambda

La función reutiliza un Lambda Layer que provee comuninación con una base de datos Postgresql. El código del layer está disponible en: https://github.com/mphsi/ruby_lambda_pg_layer

Para generar el paquete .zip ejecutar zip -r function.zip lambda_function.rb ./lib/

