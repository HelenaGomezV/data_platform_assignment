## Adoption of SVC_AIRBYTE
1. Backup/verificar el Terraform state de producción.
2. Confirmar las direcciones actuales de los 3 recursos AWS.
3. Mover esas direcciones al módulo con terraform state mv.
4. Importar SVC_AIRBYTE porque fue creado manualmente.
5. Ejecutar terraform plan.
6. Revisar que no haya destroy ni replacement.
7. Solo después permitir apply mediante CI.